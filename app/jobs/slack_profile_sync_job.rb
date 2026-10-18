class SlackProfileSyncJob < ApplicationJob
  queue_as :literally_whenever

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    enqueue_limit: 1,
    perform_limit: 1,
    key: -> { "slack_profile_sync_job_#{arguments.first}" }
  )

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user&.slack_uid.present?

    unless user.update_from_cachet
      retry_job(wait: 1.minute) if executions < 5
      return
    end

    user.save! if user.changed?
  rescue => e
    report_error(e, message: "Failed to update Slack username and avatar from Cachet for user #{user_id}")
    raise
  end
end
