# frozen_string_literal: true

if Rails.env.production?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    privacy_event = lambda do |event|
      url = event.request&.url
      Thread.current[:privacy_request] || Rack::Utils.unescape_path(url.to_s.split("?").first.to_s).squeeze("/").include?("/api/privacy/")
    end
    config.before_send = ->(event, _hint) { event unless privacy_event.call(event) }
    config.before_send_transaction = ->(event, _hint) { event unless privacy_event.call(event) }
    config.before_breadcrumb = ->(breadcrumb, _hint) { breadcrumb unless Thread.current[:privacy_request] }
    config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
    config.send_default_pii = true
    # Error events keep the default sample_rate of 1.0 so no exceptions are dropped.
    config.traces_sampler = lambda do |context|
      next 0.0 if Thread.current[:privacy_request]
      context[:parent_sampled].nil? ? 0.25 : context[:parent_sampled]
    end
    # Relative to sampled traces; privacy requests never start a profile.
    config.profiles_sample_rate = 1.0

    # Enable sending logs to Sentry
    config.enable_logs = true
    # Patch Ruby logger to forward logs
    config.enabled_patches = [ :logger ]
    # Send every warning and error log, but only a quarter of lower severity logs.
    config.before_send_log = lambda do |log|
      log unless Thread.current[:privacy_request] || (!%i[warn error fatal].include?(log.level) && rand >= 0.25)
    end
  end
end
