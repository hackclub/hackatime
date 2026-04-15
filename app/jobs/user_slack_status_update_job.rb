class UserSlackStatusUpdateJob < ApplicationJob
  queue_as :latency_10s

  BATCH_SIZE = 25

  def perform
    User.where(uses_slack_status: true).find_each(batch_size: BATCH_SIZE) do |user|
      begin
        Users::SlackIntegrationService.new(user).update_slack_status
      rescue => e
        report_error(e, message: "Failed to update Slack status for user #{user.slack_uid}")
      end
    end
  end
end
