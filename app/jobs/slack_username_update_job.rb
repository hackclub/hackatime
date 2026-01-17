class SlackUsernameUpdateJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  # Limits concurrency to 1 job per date
  good_job_control_concurrency_with(
    total: 1,
    drop: true
  )

  def perform
    User
      .where.not(slack_uid: nil)
      .order(Arel.sql("slack_synced_at IS NOT NULL, slack_synced_at ASC"))
      .limit(100)
      .each do |user|
        begin
          user.update_from_slack
          user.save!
        rescue => e
          Rails.logger.error "Failed to update Slack username and avatar for user #{user.id}: #{e.message}"
        end
      end
  end
end
