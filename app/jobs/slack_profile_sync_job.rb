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
    return unless user&.authentication_allowed? && !user.pending_deletion? && user.slack_uid.present?

    slack_uid = user.slack_uid
    user_data = user.raw_slack_user_info
    return unless user_data.present?

    user.with_lock do
      return unless user.authentication_allowed? && !user.pending_deletion? && user.slack_uid == slack_uid

      user.apply_slack_profile_attributes(user_data)
      user.slack_synced_at = Time.current
      user.save!
    end
  rescue SlackIntegration::RateLimitedError => e
    raise if executions >= 5

    polynomial_delay = executions**4 + (Kernel.rand * executions**4 * 0.15) + 2
    retry_job(wait: [ e.retry_after, polynomial_delay ].max.seconds)
  rescue => e
    report_error(e, message: "Failed to update Slack username and avatar for user #{user_id}")
    raise
  end
end
