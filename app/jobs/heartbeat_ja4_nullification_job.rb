class HeartbeatJa4NullificationJob < ApplicationJob
  queue_as :literally_whenever

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "heartbeat_ja4_nullification_#{arguments.first}" }
  )

  retry_on StandardError, wait: ->(executions) { [ executions**2, 60 ].min.seconds }, attempts: :unlimited

  def perform(nullification_id = nil)
    HeartbeatRepository.ensure_mutations_enabled!
    unless nullification_id
      HeartbeatJa4Nullification.where(completed_at: nil).limit(1_000).pluck(:id).each do |id|
        self.class.perform_later(id)
      end
      return
    end

    nullification = HeartbeatJa4Nullification.find(nullification_id)
    return if nullification.completed_at?

    HeartbeatRepository.current.nullify_ja4(
      nullification.ja4_id,
      version: nullification.clickhouse_version
    )
    nullification.update!(completed_at: Time.current, last_error: nil)
  rescue => error
    nullification&.update!(last_error: "#{error.class}: #{error.message}".truncate(1_000))
    raise
  end
end
