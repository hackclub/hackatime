require "resolv"
require "ipaddr"

class WakatimeCompatibleClient
  class AuthenticationError < StandardError; end
  class TransientError < StandardError; end
  class RequestError < StandardError; end

  BLOCKED_IP_RANGES = [
    IPAddr.new("0.0.0.0/8"),
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("100.64.0.0/10"),
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("169.254.0.0/16"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.0.0.0/24"),
    IPAddr.new("192.0.2.0/24"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("198.18.0.0/15"),
    IPAddr.new("198.51.100.0/24"),
    IPAddr.new("203.0.113.0/24"),
    IPAddr.new("224.0.0.0/4"),
    IPAddr.new("240.0.0.0/4"),
    IPAddr.new("255.255.255.255/32"),
    IPAddr.new("::1/128"),
    IPAddr.new("fc00::/7"),
    IPAddr.new("fe80::/10"),
    IPAddr.new("ff00::/8")
  ].freeze

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
      raise RequestError, "Unexpected heartbeats response format"
    end
  end

  private

  def get_json(path, params: nil)
    validate_endpoint_ip!

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

  def validate_endpoint_ip!
    uri = URI.parse(@endpoint_url)
    hostname = uri.host
    return if hostname.blank?

    addresses = Resolv.getaddresses(hostname)
    raise RequestError, "Could not resolve hostname: #{hostname}" if addresses.empty?

    addresses.each do |addr_str|
      ip = IPAddr.new(addr_str)
      if BLOCKED_IP_RANGES.any? { |range| range.include?(ip) }
        raise RequestError, "Endpoint resolves to a blocked IP address"
      end
    end
  rescue Resolv::ResolvError
    raise RequestError, "Could not resolve hostname: #{uri&.host}"
  end

  def headers
    {
      "Authorization" => "Basic #{Base64.strict_encode64("#{@api_key}:")}",
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
  end
end
