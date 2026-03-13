module ErrorReporting
  extend ActiveSupport::Concern

  # Report an exception to both Sentry and Rails.logger
  # Usage: report_error(exception, message: "optional context")
  def report_error(exception, message: nil, extra: {})
    full_message = message ? "#{message}: #{exception.message}" : exception.message
    Rails.logger.error(full_message)
    Sentry.capture_exception(exception, extra: extra)
  end

  # Report a message (non-exception) to both Sentry and Rails.logger
  # Usage: report_message("Something bad happened", level: :error)
  def report_message(message, level: :error, extra: {})
    Rails.logger.send(level, message)
    Sentry.capture_message(message, level: level, extra: extra)
  end
end
