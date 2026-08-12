class HeartbeatTransferJob < ApplicationJob
  queue_as :literally_whenever

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "heartbeat_transfer_#{arguments.first}" }
  )

  retry_on StandardError, wait: ->(executions) { [ executions**2, 60 ].min.seconds }, attempts: :unlimited

  def perform(transfer_id = nil)
    unless transfer_id
      HeartbeatTransfer.where.not(status: :completed).limit(1_000).pluck(:id).each do |id|
        self.class.perform_later(id)
      end
      return
    end

    transfer = HeartbeatTransfer.find(transfer_id)
    return if transfer.completed?

    HeartbeatRepository.current.transfer_rows(transfer)
    transfer.update!(status: :completed, completed_at: Time.current, last_error: nil)
  rescue => error
    transfer&.update!(status: :failed, last_error: "#{error.class}: #{error.message}".truncate(1_000))
    raise
  end
end
