class HeartbeatAccountMergeJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: "heartbeat_serving_rebuild"
  )

  retry_on StandardError, wait: :polynomially_longer, attempts: 10

  def perform(older_user_id:, newer_user_id:)
    Clickhouse::HeartbeatWriter.merge_user_heartbeats!(
      older_user_id: older_user_id,
      newer_user_id: newer_user_id
    )
  end
end
