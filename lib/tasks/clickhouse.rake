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

      HeartbeatServingBackfillJob.perform_later(user_ids)
      last_user_id = user_ids.last
      enqueued_users += user_ids.length
      enqueued_batches += 1
      puts "Enqueued #{enqueued_users} users through user_id=#{last_user_id}"
    end

    puts "Enqueued #{enqueued_batches} batches for #{enqueued_users} users."
  end

  desc "Read-only parity benchmark for raw heartbeat queries versus serving tables"
  task benchmark_serving: :environment do
    require Rails.root.join("lib/heartbeat_serving_benchmark")
    user_ids = ENV.fetch("USER_IDS").split(",").map(&:strip).reject(&:blank?).map(&:to_i)
    iterations = ENV.fetch("ITERATIONS", 5).to_i
    all_projects = ActiveModel::Type::Boolean.new.cast(ENV.fetch("ALL_PROJECTS", false))
    results = HeartbeatServingBenchmark.new(user_ids: user_ids, iterations: iterations, all_projects: all_projects).call

    puts JSON.pretty_generate(results.map(&:to_h))
  end
end
