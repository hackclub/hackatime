class SlackUsernameUpdateJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  # Limits concurrency to 1 job at a time
  good_job_control_concurrency_with(
    total_limit: 1
  )

  def perform
    User
      .where.not(slack_uid: nil)
      .where("slack_synced_at IS NULL OR slack_synced_at < ?", 1.day.ago)
      .find_each { |user| SlackProfileSyncJob.perform_later(user.id) }
  end
end
