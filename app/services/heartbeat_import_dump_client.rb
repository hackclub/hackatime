class HeartbeatImportDumpClient
  class AuthenticationError < StandardError; end
  class TransientError < StandardError; end
  class RequestError < StandardError; end

  BASE_URLS = {
    "wakatime_dump" => "https://wakatime.com/api/v1",
    "hackatime_v1_dump" => "https://waka.hackclub.com/api/v1"
  }.freeze

  TIMEOUTS = {
    connect: 5,
    read: 60,
    write: 15
  }.freeze

  def initialize(source_kind:, api_key:)
    @source_kind = source_kind.to_s
    @endpoint_url = BASE_URLS.fetch(@source_kind)
    @api_key = api_key.to_s
  end

  def request_dump
    body = request_json(
      method: :post,
      path: "/users/current/data_dumps",
      json: { type: "heartbeats", email_when_finished: false }
    )

    normalize_dump(body.fetch("data"))
  end

  def list_dumps
    body = request_json(method: :get, path: "/users/current/data_dumps")
    Array(body["data"]).map { |dump| normalize_dump(dump) }
  end

  def download_dump(download_url)
    response = HTTP.follow.timeout(TIMEOUTS).headers(download_headers(download_url)).get(download_url)
    handle_response_errors(response)
    response.to_s
  rescue HTTP::TimeoutError, HTTP::ConnectionError => e
    raise TransientError, e.message
  end

  def self.base_url_for(source_kind)
    BASE_URLS.fetch(source_kind.to_s)
  end

  private

  def request_json(method:, path:, json: nil)
    request = HTTP.timeout(TIMEOUTS).headers(headers)
    response = if json.nil?
      request.public_send(method, "#{@endpoint_url}#{path}")
    else
      request.public_send(method, "#{@endpoint_url}#{path}", json:)
    end

    handle_response_errors(response)
    JSON.parse(response.to_s)
  rescue HTTP::TimeoutError, HTTP::ConnectionError => e
    raise TransientError, e.message
  rescue JSON::ParserError
    raise RequestError, "Invalid JSON response"
  end

  def handle_response_errors(response)
    status = response.status.to_i
    raise AuthenticationError, "Authentication failed (#{status})" if [ 401, 403 ].include?(status)
    raise TransientError, "Request failed with status #{status}" if status == 408 || status == 429 || status >= 500
    raise RequestError, "Request failed with status #{status}" unless response.status.success?
  end

  def normalize_dump(dump)
    payload = dump.respond_to?(:with_indifferent_access) ? dump.with_indifferent_access : dump.to_h.with_indifferent_access

    {
      id: payload[:id].to_s,
      status: payload[:status].to_s,
      percent_complete: payload[:percent_complete].to_f,
      download_url: payload[:download_url].presence,
      type: payload[:type].to_s,
      is_processing: ActiveModel::Type::Boolean.new.cast(payload[:is_processing]),
      is_stuck: ActiveModel::Type::Boolean.new.cast(payload[:is_stuck]),
      has_failed: ActiveModel::Type::Boolean.new.cast(payload[:has_failed]),
      expires: payload[:expires],
      created_at: payload[:created_at]
    }
  end

  def headers
    {
      "Authorization" => "Basic #{Base64.strict_encode64(basic_auth_credential)}",
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }
  end

  def download_headers(download_url)
    uri = URI.parse(download_url)
    endpoint_uri = URI.parse(@endpoint_url)

    if uri.host == endpoint_uri.host
      headers.merge("Accept" => "application/json,application/octet-stream,*/*")
    else
      { "Accept" => "application/json,application/octet-stream,*/*" }
    end
  rescue URI::InvalidURIError
    { "Accept" => "application/json,application/octet-stream,*/*" }
  end

  def basic_auth_credential
    @source_kind == "wakatime_dump" ? "#{@api_key}:" : @api_key
  end
end
