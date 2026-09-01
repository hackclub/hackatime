class UserSlackStatusUpdateJob < ApplicationJob
  queue_as :latency_10s

  retry_on HTTP::TimeoutError, HTTP::ConnectionError, JSON::ParserError,
    wait: :polynomially_longer, attempts: 3 do |job, error|
      user_id = job.arguments.first
      job.report_error(
        error,
        message: "Failed to update Slack status for user #{user_id}",
        extra: { user_id: }
      )
    end

  def perform(user_id)
    User.find_by(id: user_id)&.update_slack_status
  end
end
