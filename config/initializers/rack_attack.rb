# config/initializers/rack_attack.rb

class Rack::Attack
  # kill switch in case you really wanna
  Rack::Attack.enabled = ENV.key?("RACK_ATTACK_ENABLED") ? ENV["RACK_ATTACK_ENABLED"] == "true" : Rails.env.production?

  if ENV["RACK_ATTACK_BYPASS"].present?
    begin
      bypass_value = ENV["RACK_ATTACK_BYPASS"].strip
      TOKENS = bypass_value.split(",").map(&:strip).reject(&:empty?).freeze
      Rails.logger.info "RACK_ATTACK_BYPASS loaded #{TOKENS.length} let me in tokens"
    rescue => e
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

  # Always allow requests from bogon ips
  # (blocklist & throttles are skipped)
  Rack::Attack.safelist("allow from bogon ips") do |req|
    # max, thats a weird way, check out this method i stole from stack overflow
    ip = IPAddr.new(req.ip)
    ip.loopback? || ip.private?
  rescue IPAddr::InvalidAddressError
    false
  end

  Rack::Attack.blocklist('block non-cloudflare') do |req|
    !req.cloudflare?
  end

  Rack::Attack.safelist("admin abooze") do |req|
    req.path.start_with?("/api/admin/")
  end

  Rack::Attack.throttle("general", limit: 300, period: 1.minute) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  Rack::Attack.throttle("posts by ip", limit: 60, period: 5.minutes) do |req|
    req.ip if req.post?
  end

  Rack::Attack.throttle("auth requests", limit: 5, period: 1.minute) do |req|
    req.ip if req.path.in?([ "/login", "/signup", "/auth", "/sessions" ]) && req.post?
  end

  Rack::Attack.throttle("api requests", limit: 600, period: 1.hour) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  Rack::Attack.throttle("heartbeat api", limit: 10000, period: 1.hour) do |req|
    req.ip if req.path.start_with?("/api/hackatime/v1/users/current/heartbeats")
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
