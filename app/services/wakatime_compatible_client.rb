class WakatimeCompatibleClient
  class AuthenticationError < StandardError; end
  class TransientError < StandardError; end
  class RequestError < StandardError; end

  def initialize(endpoint_url:, api_key:)
    @endpoint_url = endpoint_url.to_s.sub(%r{/*\z}, "")
    @api_key = api_key.to_s
  end

  def fetch_all_time_since_today_start_date
    body = get_json("/users/current/all_time_since_today")
    start_date = body.dig("data", "range", "start_date") ||
      body.dig("data", "start_date") ||
      body.dig("range", "start_date")
    raise RequestError, "Missing start_date in all_time_since_today response" if start_date.blank?

    Date.iso8601(start_date.to_s)
  rescue ArgumentError
    raise RequestError, "Invalid start_date in all_time_since_today response"
  end

  def fetch_heartbeats(date:)
    body = get_json("/users/current/heartbeats", params: { date: date.iso8601 })

    if body.is_a?(Array)
      body
    elsif body["data"].is_a?(Array)
      body["data"]
    elsif body["heartbeats"].is_a?(Array)
      body["heartbeats"]
    else
      []
    end
  end

  private

  def get_json(path, params: nil)
    response = HTTP.timeout(connect: 5, read: 30, write: 10)
      .headers(headers)
      .get("#{@endpoint_url}#{path}", params:)

    status = response.status.to_i
    raise AuthenticationError, "Authentication failed (#{status})" if [ 401, 403 ].include?(status)
    raise TransientError, "Request failed with status #{status}" if status == 408 || status == 429 || status >= 500
    raise RequestError, "Request failed with status #{status}" unless response.status.success?

    JSON.parse(response.to_s)
  rescue HTTP::TimeoutError, HTTP::ConnectionError => e
    raise TransientError, e.message
  rescue JSON::ParserError
    raise RequestError, "Invalid JSON response"
  end

  def headers
    {
      "Authorization" => "Basic #{Base64.strict_encode64("#{@api_key}:")}",
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
  end
end
