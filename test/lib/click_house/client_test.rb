require "test_helper"

class ClickHouse::ClientTest < ActiveSupport::TestCase
  class FailingConnection
    attr_reader :finished

    def initialize(error)
      @error = error
    end

    def request(*) = raise(@error)
    def active? = true
    def finish = @finished = true
  end

  class TimeoutConnection
    attr_accessor :open_timeout, :read_timeout, :write_timeout

    def initialize
      @open_timeout = 5
      @read_timeout = 60
      @write_timeout = 60
    end
  end

  class ReconnectingClient < ClickHouse::Client
    attr_reader :connections

    def initialize
      super("http://default:@clickhouse:8123/hackatime_test")
      @connections = []
    end

    private

    def connection
      http = Thread.current[@connection_key]
      unless http
        http = TimeoutConnection.new
        Thread.current[@connection_key] = http
        connections << http
      end
      apply_timeouts(http)
      http
    end

    def close_connection
      Thread.current[@connection_key] = nil
    end
  end

  test "transport failures close the persistent connection" do
    [ Timeout::Error.new("timed out"), Errno::ECONNRESET.new ].each do |error|
      connection = FailingConnection.new(error)
      client = ClickHouse::Client.new("http://default:@clickhouse:8123/hackatime_test")
      client.singleton_class.define_method(:connection) do
        Thread.current[@connection_key] ||= connection
      end

      assert_raises(error.class) { client.select("SELECT 1") }

      assert connection.finished
      key = client.instance_variable_get(:@connection_key)
      assert_nil Thread.current[key]
    end
  end

  test "JSON inserts preserve the exact IEEE-754 value" do
    client = ClickHouse::Client.new("http://default:@clickhouse:8123/hackatime_test")
    value = 1_786_463_014.4097862

    decimal = client.send(:serialize_json_value, { "time" => value }).fetch("time")

    assert_equal value, Float(decimal)
    assert_operator decimal.length, :>, value.to_s.length
  end

  test "requests pin the JSON number compatibility settings" do
    client = ClickHouse::Client.new("http://default:@clickhouse:8123/hackatime_test")

    settings = client.send(:request_parameters)

    assert_equal 1, settings.fetch("input_format_json_read_numbers_as_strings")
    assert_equal 0, settings.fetch("output_format_json_quote_64bit_floats")
    assert_equal 0, settings.fetch("output_format_json_quote_64bit_integers")
  end

  test "temporary timeouts are restored after success and failure" do
    connection = TimeoutConnection.new
    client = ClickHouse::Client.new("http://default:@clickhouse:8123/hackatime_test")
    client.singleton_class.define_method(:connection) { connection }

    client.with_timeouts(open_timeout: 1, read_timeout: 2, write_timeout: 3) do
      assert_equal [ 1, 2, 3 ], [ connection.open_timeout, connection.read_timeout, connection.write_timeout ]
    end
    assert_equal [ 5, 60, 60 ], [ connection.open_timeout, connection.read_timeout, connection.write_timeout ]

    assert_raises(RuntimeError) do
      client.with_timeouts(open_timeout: 1, read_timeout: 2, write_timeout: 3) { raise "failed" }
    end
    assert_equal [ 5, 60, 60 ], [ connection.open_timeout, connection.read_timeout, connection.write_timeout ]
  end

  test "temporary timeouts survive a connection replacement" do
    client = ReconnectingClient.new

    client.with_timeouts(open_timeout: 1, read_timeout: 2, write_timeout: 3) do
      first = client.send(:connection)
      client.send(:close_connection)
      second = client.send(:connection)

      assert_not_same first, second
      assert_equal [ 1, 2, 3 ], [ second.open_timeout, second.read_timeout, second.write_timeout ]
    end
    actual = client.connections.last.then do |connection|
      [ connection.open_timeout, connection.read_timeout, connection.write_timeout ]
    end
    assert_equal [ 5, 60, 60 ], actual
  end
end
