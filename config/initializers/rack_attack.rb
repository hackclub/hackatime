# config/initializers/rack_attack.rb

require "base64"

class Rack::Attack
  Rack::Attack.enabled = true

  if ENV["RACK_ATTACK_BYPASS"].present?
    begin
      bypass_value = ENV["RACK_ATTACK_BYPASS"].strip
      TOKENS = bypass_value.split(",").map(&:strip).reject(&:empty?).freeze
      Rails.logger.info "RACK_ATTACK_BYPASS loaded #{TOKENS.length} let me in tokens"
    rescue => e
      Sentry.capture_exception(e)
      Rails.logger.error "RACK_ATTACK_BYPASS failed to read, you fucked it up #{e.message} raw: #{ENV['RACK_ATTACK_BYPASS'].inspect}"
      TOKENS = [].freeze
    end
    Rack::Attack.safelist("bypass with valid token") do |request|
      bypass = request.env["HTTP_RACK_ATTACK_BYPASS"]
      bypass.present? && TOKENS.include?(bypass)
    end
  else
    TOKENS = [].freeze
  end

  def self.heartbeat_request?(req)
    req.path =~ %r{\A/api/hackatime/v1/users/[^/]+/heartbeats(?:\.bulk)?\z}
  end

  def self.authenticated_credential_id(req)
    sources, api_keys, oauth, oauth_scopes = credential_policy(req.path)
    return unless sources

    source, token = credential_from(req, sources)
    token = normalize_credential(token)
    return if token.blank?

    if api_keys
      api_key_id = ApiKey.where(token: token).pick(:id)
      return "api_key:#{api_key_id}" if api_key_id
    end
    return unless source == :bearer && oauth

    oauth_token = Doorkeeper::AccessToken.by_token(token)
    oauth_valid = oauth_scopes ? oauth_token&.acceptable?(oauth_scopes) : oauth_token&.accessible?
    "oauth_token:#{oauth_token.id}" if oauth_valid
  end

  def self.credential_policy(path)
    normalized_path = path.chomp("/")

    case normalized_path
    when "/api/v1/authenticated/me"
      [ [ :bearer ], false, true, [ "profile" ] ]
    when "/api/v1/authenticated/hours", "/api/v1/authenticated/streak",
         "/api/v1/authenticated/projects", "/api/v1/authenticated/heartbeats/latest"
      [ [ :bearer ], false, true, [ "read" ] ]
    when "/api/v1/authenticated/api_keys"
      [ [ :bearer ], false, true, nil ]
    when %r{\A/api/hackatime/v1/}
      [ %i[bearer basic query], true, false, nil ]
    when "/api/v1/my/heartbeats", "/api/v1/my/heartbeats/most_recent"
      [ %i[bearer basic], true, true, [ "read" ] ]
    end
  end

  def self.credential_from(req, sources)
    scheme, token = req.get_header("HTTP_AUTHORIZATION").to_s.split(/\s+/, 2)
    return [ :bearer, token ] if sources.include?(:bearer) && scheme&.casecmp?("Bearer")
    if sources.include?(:basic) && scheme&.casecmp?("Basic")
      return [ :basic, Base64.strict_decode64(token.to_s) ]
    end

    [ :query, req.GET["api_key"] ] if sources.include?(:query)
  rescue ArgumentError
    nil
  end

  def self.normalize_credential(token)
    token = token.to_s
    return if token.encoding == Encoding::UTF_8 && !token.valid_encoding?

    token.encode(Encoding::UTF_8)
  rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    nil
  end

  # Always allow requests from bogon ips
  # (blocklist & throttles are skipped)
  Rack::Attack.safelist("allow from bogon ips") do |req|
    # max, thats a weird way, check out this method i stole from stack overflow
    ip = IPAddr.new(req.ip)
    ip.loopback? || ip.private?
  rescue IPAddr::InvalidAddressError
    false
  end

  Rack::Attack.blocklist("block non-cloudflare") do |req|
    !req.cloudflare?
  end

  Rack::Attack.throttle("admin abooze", limit: 300, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/admin/")
  end

  Rack::Attack.throttle("general", limit: 300, period: 1.minute) do |req|
    unless req.path.start_with?("/assets")
      authenticated_credential_id(req) || "ip:#{req.ip}"
    end
  end

  Rack::Attack.throttle("posts by ip", limit: 60, period: 5.minutes) do |req|
    req.ip if req.post? && !heartbeat_request?(req)
  end

  Rack::Attack.throttle("documentation feedback by ip", limit: 20, period: 1.hour) do |req|
    req.ip if req.post? && req.path.match?(%r{\A/docs/feedback/?\z})
  end

  Rack::Attack.throttle("auth requests", limit: 5, period: 1.minute) do |req|
    req.ip if req.path.in?([ "/login", "/signup", "/auth", "/sessions" ]) && req.post?
  end

  Rack::Attack.throttle("api requests", limit: 10000, period: 1.hour) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # if ur stuff is going faster than this then we got a problem dude
  Rack::Attack.throttle("heartbeat uploads", limit: 360, period: 1.minute) do |req|
    req.ip if req.post? && heartbeat_request?(req)
  end

  # lets actually log things? thanks
  ActiveSupport::Notifications.subscribe(/rack_attack/) do |name, start, finish, request_id, payload|
    req = payload[:request]
    user_agent = req.env["HTTP_USER_AGENT"]

    case name
    when "rack_attack.throttle"
      Rails.logger.warn "[Rack::Attack][Throttle] IP: #{req.ip}, Path: #{req.path}, Rule: #{payload[:matched]}, UA: #{user_agent}"
    when "rack_attack.blocklist"
      Rails.logger.warn "[Rack::Attack][Block] IP: #{req.ip}, Path: #{req.path}, Rule: #{payload[:matched]}, UA: #{user_agent}"
    when "rack_attack.safelist"
      Rails.logger.info "[Rack::Attack][Bypass] IP: #{req.ip}, Path: #{req.path}, Rule: #{payload[:matched]}"
    end
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    match = request.env["rack.attack.match_data"] || {}
    period = match[:period] || 60
    limit = match[:limit] || "unknown"

    now = Time.current
    window_start = now.to_i - (now.to_i % period)
    reset_time = window_start + period
    retry_after = reset_time - now.to_i

    headers = {
      "Content-Type" => "application/json",
      "Retry-After" => retry_after.to_s,
      "X-RateLimit-Limit" => limit.to_s,
      "X-RateLimit-Remaining" => "0",
      "X-RateLimit-Reset" => reset_time.to_s,
      "X-RateLimit-Reset-At" => Time.at(reset_time).iso8601
    }

    res = {
      error: "Rate limit exceeded",
      message: "Woah there, way too fast, take a chill pill speedy gonzales!",
      retry_after: retry_after,
      reset_at: Time.at(reset_time).iso8601
    }

    [ 429, headers, [ res.to_json ] ]
  end
end
