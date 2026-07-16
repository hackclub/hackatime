class HeartbeatServingRebuildJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    perform_limit: 1,
    key: "heartbeat_serving_rebuild"
  )

  def perform(user_ids, reason:)
    Array(user_ids).map(&:to_i).uniq.each do |user_id|
      HeartbeatIntervals::UserRebuilder.call(user_id: user_id, reason: reason)
    end
  end
end
