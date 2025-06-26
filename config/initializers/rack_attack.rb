# config/initializers/rack_attack.rb

class Rack::Attack
  # kill switch in case you really wanna
  Rack::Attack.enabled = Rails.env.production? || ENV["RACK_ATTACK_ENABLED"] == "true"

  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new if Rails.env.development?

  if ENV["RACK_ATTACK_BYPASS"].present?
    begin
      bypass_value = ENV["RACK_ATTACK_BYPASS"].strip
      bypass_value = bypass_value.gsub(/\A['"]|['"]\z/, "")
      bypass_value = bypass_value.gsub(/\\\"/, '"') if bypass_value.include?('\\\"')

      TOKENS = JSON.parse(bypass_value).freeze
      unless TOKENS.is_a?(Array)
        Rails.logger.warn "RACK_ATTACK_BYPASS should be a array, tf is this #{TOKENS.class}"
        TOKENS = [].freeze
      end
      Rails.logger.info "RACK_ATTACK_BYPASS loaded #{TOKENS.length} let me in tokens"
    rescue JSON::ParserError => e
      Rails.logger.error "RACK_ATTACK_BYPASS failed to read, you fucked it up #{e.message} raw: #{ENV['RACK_ATTACK_BYPASS'].inspect}"
      TOKENS = [].freeze
    end

    Rack::Attack.safelist("mark any authenticated access safe") do |request|
      bypass = request.env["HTTP_RACK_ATTACK_BYPASS"] || request.env["HTTP_X_RACK_ATTACK_BYPASS"]
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

  Rack::Attack.throttle("general", limit: 300, period: 1.minute) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  Rack::Attack.throttle("posts by ip", limit: 60, period: 5.minutes) do |req|
    req.ip if req.post?
  end

  Rack::Attack.throttle("auth requests", limit: 5, period: 1.minute) do |req|
    req.ip if req.path.in?([ "/login", "/signup", "/auth", "/sessions" ]) && req.post?
  end

  Rack::Attack.throttle("api requests", limit: 1000, period: 1.hour) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  Rack::Attack.throttle("heartbeat api", limit: 10000, period: 1.hour) do |req|
    req.ip if req.path.start_with?("/api/hackatime/v1/users/current/heartbeats")
  end

  Rack::Attack.blocklist("block sussy") do |req|
    # somehow we can do this, so lets get all the cringe ones outta here
    user_agent = req.env["HTTP_USER_AGENT"].to_s.downcase
    sussy = %w[scanner bot crawler wget curl python-requests]

    # if you spoof this i swear your actually cringe
    no_cap = %w[wakatime hackatime github slack discord uptime kuma]

    is_sus = sussy.any? { |agent| user_agent.include?(agent) }
    allowed = no_cap.any? { |agent| user_agent.include?(agent) }

    is_sus && !allowed
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
    retry_after = match[:period] || 60
    limit = match[:limit] || "unknown"

    now = Time.current
    reset_time = (now + retry_after).to_i

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
