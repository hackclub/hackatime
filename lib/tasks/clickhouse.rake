namespace :clickhouse do
  desc "Enqueue correction-aware serving-table backfills for every live heartbeat user"
  task enqueue_serving_backfill: :environment do
    batch_size = ENV.fetch("BATCH_SIZE", 25).to_i.clamp(1, 1_000)
    last_user_id = ENV.fetch("START_AFTER", 0).to_i
    enqueued_users = 0
    enqueued_batches = 0

    loop do
      user_ids = Clickhouse::Heartbeat.unscoped.final
        .where(deleted_at: nil)
        .where("user_id > ?", last_user_id)
        .distinct
        .order(:user_id)
        .limit(batch_size)
        .pluck(:user_id)
        .map(&:to_i)
      break if user_ids.empty?

      job = HeartbeatServingRebuildJob.perform_later(user_ids, reason: "serving_backfill")
      unless job&.successfully_enqueued?
        message = "Failed to enqueue users #{user_ids.join(', ')}. Resume with START_AFTER=#{last_user_id}"
        warn message
        raise(job&.enqueue_error || ActiveJob::EnqueueError.new(message))
      end

      last_user_id = user_ids.last
      enqueued_users += user_ids.length
      enqueued_batches += 1
      puts "Enqueued #{enqueued_users} users through user_id=#{last_user_id}"
    end

    puts "Enqueued #{enqueued_batches} batches for #{enqueued_users} users."
  end
end
