class PosthogService
  class << self
    include ErrorReporting
    def capture(user_or_id, event, properties = {})
      return unless $posthog

      distinct_id = user_or_id.is_a?(User) ? user_or_id.id.to_s : user_or_id.to_s

      $posthog.capture(
        distinct_id: distinct_id,
        event: event,
        properties: properties
      )
    rescue => e
      report_error(e, message: "PostHog capture error")
    end

    def identify(user, properties = {})
      return unless $posthog

      $posthog.identify(
        distinct_id: user.id.to_s,
        properties: {
          slack_uid: user.slack_uid,
          username: user.username,
          timezone: user.timezone,
          country_code: user.country_code,
          created_at: user.created_at&.iso8601,
          admin_level: user.admin_level
        }.merge(properties)
      )
    rescue => e
      report_error(e, message: "PostHog identify error")
    end

    def capture_once_per_day(user, event, properties = {})
      return unless $posthog

      cache_key = "posthog_daily:#{user.id}:#{event}:#{Date.current}"
      return if Rails.cache.exist?(cache_key)

      capture(user, event, properties)
      Rails.cache.write(cache_key, true, expires_at: Date.current.end_of_day + 1.hour)
    rescue => e
      report_error(e, message: "PostHog capture_once_per_day error")
    end
  end
end
