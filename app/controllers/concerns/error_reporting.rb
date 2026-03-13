# frozen_string_literal: true

module ErrorReporting
  extend ActiveSupport::Concern

  # Prefer this over calling Sentry and logger separately to keep reporting consistent.
  # Usage: report_error(exception, message: "optional context")
  def report_error(exception, message: nil, extra: {})
    Rails.logger.error(message || exception.message)
    Sentry.capture_exception(exception, extra: extra.merge(message: message).compact)
  end

  # Prefer this for non-exception events that still warrant Sentry visibility.
  # Usage: report_message("Something bad happened", level: :error)
  def report_message(message, level: :error, extra: {})
    Rails.logger.send(level, message)
    Sentry.capture_message(message, level: level, extra: extra)
  end
end
