# frozen_string_literal: true

if Rails.env.production?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
    config.send_default_pii = true
    # Error events keep the default sample_rate of 1.0 so no exceptions are dropped.
    config.traces_sample_rate = 0.25
    # Relative to traces_sample_rate, so this profiles every sampled trace.
    config.profiles_sample_rate = 1.0

    # Enable sending logs to Sentry
    config.enable_logs = true
    # Patch Ruby logger to forward logs
    config.enabled_patches = [ :logger ]
    # Send every warning and error log, but only a quarter of lower severity logs.
    config.before_send_log = lambda do |log|
      log if %i[warn error fatal].include?(log.level) || rand < 0.25
    end
  end
end
