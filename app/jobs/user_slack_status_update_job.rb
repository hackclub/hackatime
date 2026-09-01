class UserSlackStatusUpdateJob < ApplicationJob
  queue_as :latency_10s

  MAX_ATTEMPTS = 3

  retry_on HTTP::TimeoutError, HTTP::ConnectionError, JSON::ParserError, SlackIntegration::ServerError,
    wait: :polynomially_longer, attempts: MAX_ATTEMPTS do |job, error|
      user_id = job.arguments.first
      job.report_error(
        error,
        message: "Failed to update Slack status for user #{user_id}",
        extra: { user_id: }
      )
    end

  def perform(user_id)
    User.find_by(id: user_id)&.update_slack_status
  rescue SlackIntegration::ServerError
    raise
  rescue SlackIntegration::RateLimitedError => e
    if executions < MAX_ATTEMPTS
      retry_job(wait: e.retry_after.seconds)
    else
      report_error(
        e,
        message: "Failed to update Slack status for user #{user_id}",
        extra: { user_id: }
      )
    end
  rescue SlackIntegration::ApiError => e
    report_error(
      e,
      message: "Failed to update Slack status for user #{user_id}",
      extra: { user_id: }
    )
    raise
  end
end
