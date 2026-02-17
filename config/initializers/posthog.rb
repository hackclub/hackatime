require "posthog"

if ENV["POSTHOG_API_KEY"].present?
  $posthog = PostHog::Client.new({
    api_key: ENV["POSTHOG_API_KEY"],
    host: ENV.fetch("POSTHOG_HOST", "https://us.i.posthog.com"),
    on_error: proc { |status, msg| Rails.logger.error "PostHog error: #{status} - #{msg}" }
  })
else
  $posthog = nil
end
