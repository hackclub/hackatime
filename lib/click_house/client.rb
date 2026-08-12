require "json"
require "net/http"
require "timeout"
require "uri"

module ClickHouse
  class Client
    class Error < StandardError; end

    DEFAULT_SETTINGS = {
      defer_partition_pruning_after_final: 0,
      do_not_merge_across_partitions_select_final: 1,
      materialized_views_ignore_errors: 0
    }.freeze

    def self.current
      @current ||= new(ENV.fetch("CLICKHOUSE_URL"))
    end

    def initialize(url)
      @uri = URI(url)
      @database = @uri.path.delete_prefix("/").presence || "default"
      @username = URI.decode_www_form_component(@uri.user || "default")
      @password = URI.decode_www_form_component(@uri.password || "")
      @uri.path = "/"
      @uri.user = @uri.password = nil
      @connection_key = "click_house_connection_#{object_id}".to_sym
    end

    def select(sql, params: {}, settings: {})
      select_result(sql, params:, settings:).fetch("data")
    end

    def select_result(sql, params: {}, settings: {})
      response = request(
        sql.include?(" FORMAT ") ? sql : "#{sql.rstrip} FORMAT JSON",
        query: request_parameters(params:, settings:)
      )
      JSON.parse(response)
    end

    def execute(sql, settings: {})
      request(sql, query: request_parameters(settings:))
    end

    def insert_json_each_row(table, rows, settings: {})
      return if rows.empty?

      columns = rows.first.keys
      query = "INSERT INTO #{identifier(table)} (#{columns.map { |column| identifier(column) }.join(', ')}) FORMAT JSONEachRow"
      body = rows.map { |row| JSON.generate(serialize_json_value(row)) }.join("\n") << "\n"
      request(body, query: request_parameters(settings:).merge(query:))
    end

    def each_json_each_row(sql, settings: {})
      return enum_for(__method__, sql, settings:) unless block_given?

      stream_request("#{sql.rstrip} FORMAT JSONEachRow", query: request_parameters(settings:)) do |chunk, buffer|
        buffer << chunk
        while (newline = buffer.index("\n"))
          line = buffer.slice!(0..newline).strip
          yield JSON.parse(line) unless line.empty?
        end
      end
    end

    def identifier(value)
      "`#{value.to_s.gsub('`', '``')}`"
    end

    private

    def stream_request(body, query: {})
      uri = @uri.dup
      uri.query = URI.encode_www_form({ database: @database }.merge(query))
      request = Net::HTTP::Post.new(uri)
      request.basic_auth(@username, @password)
      request["Content-Type"] = "text/plain; charset=utf-8"
      request.body = body
      buffer = +""

      connection.request(request) do |response|
        unless response.is_a?(Net::HTTPSuccess)
          raise Error, "ClickHouse returned HTTP #{response.code}: #{response.body.to_s.squish.truncate(1_000)}"
        end

        response.read_body { |chunk| yield chunk, buffer }
      end
      yield "\n", buffer if buffer.present?
    rescue StandardError
      close_connection
      raise
    end

    def request(body, query: {})
      uri = @uri.dup
      uri.query = URI.encode_www_form({ database: @database }.merge(query))
      request = Net::HTTP::Post.new(uri)
      request.basic_auth(@username, @password)
      request["Content-Type"] = "text/plain; charset=utf-8"
      request.body = body

      response = connection.request(request)
      return response.body if response.is_a?(Net::HTTPSuccess)

      raise Error, "ClickHouse returned HTTP #{response.code}: #{response.body.to_s.squish.truncate(1_000)}"
    rescue Timeout::Error, SocketError, IOError, EOFError, SystemCallError, OpenSSL::SSL::SSLError
      close_connection
      raise
    end

    def connection
      Thread.current[@connection_key] ||= Net::HTTP.start(
        @uri.host,
        @uri.port,
        use_ssl: @uri.scheme == "https",
        open_timeout: 5,
        read_timeout: 60,
        write_timeout: 60
      )
    end

    def close_connection
      connection = Thread.current[@connection_key]
      connection&.finish if connection&.active?
    rescue Timeout::Error, SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError
    ensure
      Thread.current[@connection_key] = nil
    end

    def request_parameters(params: {}, settings: {})
      DEFAULT_SETTINGS.stringify_keys.merge(settings.stringify_keys).merge(
        params.to_h { |name, value| [ "param_#{name}", serialize_parameter(value) ] }
      )
    end

    def serialize_parameter(value)
      case value
      when Array, Hash then JSON.generate(value)
      when Time, DateTime then value.utc.strftime("%Y-%m-%d %H:%M:%S.%6N")
      when Date then value.iso8601
      when true then 1
      when false then 0
      else value.to_s
      end
    end

    def serialize_json_value(value)
      case value
      when Float then exact_decimal(value)
      when Array then value.map { |item| serialize_json_value(item) }
      when Hash then value.transform_values { |item| serialize_json_value(item) }
      else value
      end
    end

    def exact_decimal(value)
      raise ArgumentError, "non-finite number" unless value.finite?
      return "-0.0" if value.zero? && (1.0 / value).negative?

      numerator, denominator = value.to_r.then { |rational| [ rational.numerator, rational.denominator ] }
      return numerator.to_s if denominator == 1

      scale = denominator.bit_length - 1
      digits = (numerator.abs * (5**scale)).to_s.rjust(scale + 1, "0")
      integer = digits[0...-scale]
      fraction = digits[-scale..].sub(/0+\z/, "")
      decimal = fraction.empty? ? integer : "#{integer}.#{fraction}"
      numerator.negative? ? "-#{decimal}" : decimal
    end
  end
end
