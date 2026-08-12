class HeartbeatDeliveryJob < ApplicationJob
  queue_as :literally_whenever

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "#{self.class.name}:#{arguments.first || 'global'}" }
  )

  retry_on StandardError, wait: ->(executions) { [ executions**2, 60 ].min.seconds }, attempts: :unlimited

  def perform(user_id = nil)
    processed = HeartbeatRepository.current.reconcile_store(user_id:)
    self.class.perform_later(user_id) if processed == 1_000
  end
end
