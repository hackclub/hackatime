class HeartbeatDeletionJob < ApplicationJob
  queue_as :literally_whenever

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "heartbeat_deletion_#{arguments.first}" }
  )

  retry_on StandardError, wait: ->(executions) { [ executions**2, 60 ].min.seconds }, attempts: :unlimited

  def perform(deletion_id = nil)
    unless deletion_id
      HeartbeatDeletion.where.not(status: :completed).limit(1_000).pluck(:id).each do |id|
        self.class.perform_later(id)
      end
      return
    end

    deletion = HeartbeatDeletion.find(deletion_id)
    unless deletion.completed?
      HeartbeatRepository.current.soft_delete_user(
        deletion.user_id,
        version: deletion.clickhouse_version,
        deleted_at: deletion.created_at
      )
      deletion.update!(status: :completed, completed_at: Time.current, last_error: nil)
    end
    DeletionRequest.ready_for_deletion.where(user_id: deletion.user_id).find_each(&:complete!)
  rescue => error
    deletion&.update!(status: :failed, last_error: "#{error.class}: #{error.message}".truncate(1_000))
    raise
  end
end
