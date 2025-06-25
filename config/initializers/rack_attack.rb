# config/initializers/rack_attack.rb

class Rack::Attack
  # Always allow requests from localhost
  # (blocklist & throttles are skipped)
  Rack::Attack.safelist("allow from localhost") do |req|
    # Requests are allowed if the return value is truthy
    "127.0.0.1" == req.ip || "::1" == req.ip
  end

  # Allow an IP address to make 5 requests per second
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # Allow an IP address to make 5 POST requests per second
  throttle("post/ip", limit: 60, period: 5.minutes) do |req|
    req.ip if req.post?
  end

  # Throttle requests to /login by IP address
  throttle("login/ip", limit: 5, period: 20.seconds) do |req|
    if req.path == "/login" && req.post?
      req.ip
    end
  end

  # Throttle requests to /api by IP address
  throttle("api/ip", limit: 100, period: 5.minutes) do |req|
    if req.path.start_with?("/api")
      req.ip
    end
  end

  # Log blocked requests
  ActiveSupport::Notifications.subscribe(/rack_attack/) do |name, start, finish, request_id, payload|
    req = payload[:request]

    case name
    when "rack_attack.throttle"
      Rails.logger.warn "[Rack::Attack][Throttle] IP: #{req.ip}, Path: #{req.path}, Discriminator: #{payload[:discriminator]}, Matched: #{payload[:matched]}"
    when "rack_attack.blocklist"
      Rails.logger.warn "[Rack::Attack][Blocklist] IP: #{req.ip}, Path: #{req.path}, Discriminator: #{payload[:discriminator]}, Matched: #{payload[:matched]}"
    when "rack_attack.safelist"
      Rails.logger.info "[Rack::Attack][Safelist] IP: #{req.ip}, Path: #{req.path}, Discriminator: #{payload[:discriminator]}, Matched: #{payload[:matched]}"
    end
  end

  # Custom response for throttled requests
  self.throttled_response = lambda do |env|
    retry_after = (env["rack.attack.match_data"] || {})[:period]
    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s,
        "X-RateLimit-Limit" => env["rack.attack.matched"].to_s,
        "X-RateLimit-Remaining" => "0",
        "X-RateLimit-Reset" => (Time.now + retry_after).to_i.to_s
      },
      [ { error: "Too Many Requests", message: "Rate limit exceeded. Try again later." }.to_json ]
    ]
  end
end
