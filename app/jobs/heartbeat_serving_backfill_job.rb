class HeartbeatServingBackfillJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: "heartbeat_serving_rebuild"
  )

  def perform(user_ids)
    Array(user_ids).map(&:to_i).uniq.each do |user_id|
      HeartbeatIntervals::UserRebuilder.call(user_id: user_id, reason: "serving_backfill")
    end
  end
end
