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

  desc "Run the comprehensive endpoint, range, filter, timezone, and project serving benchmark"
  task benchmark_comprehensive: :environment do
    require Rails.root.join("lib/heartbeat_comprehensive_benchmark")
    require Rails.root.join("lib/clickhouse_benchmark_report")

    profiles = if ENV["BENCHMARK_PROFILES_FILE"].present?
      JSON.parse(File.read(ENV.fetch("BENCHMARK_PROFILES_FILE")), symbolize_names: true)
    elsif ENV["BENCHMARK_PROFILES_JSON"].present?
      JSON.parse(ENV.fetch("BENCHMARK_PROFILES_JSON"), symbolize_names: true)
    else
      ENV.fetch("USER_IDS").split(",").map(&:strip).reject(&:blank?).map { |user_id| { user_id: user_id.to_i } }
    end

    iterations = ENV.fetch("ITERATIONS", 3).to_i
    project_iterations = ENV.fetch("PROJECT_ITERATIONS", 1).to_i
    all_projects = ActiveModel::Type::Boolean.new.cast(ENV.fetch("ALL_PROJECTS", true))
    timezones = ENV.fetch("TIMEZONES", HeartbeatComprehensiveBenchmark::DEFAULT_TIMEZONES.join(",")).split(",").map(&:strip)
    timezone_user_id = ENV["TIMEZONE_USER_ID"]
    results = HeartbeatComprehensiveBenchmark.new(
      profiles:, iterations:, project_iterations:, all_projects:, timezones:, timezone_user_id:,
      progress: ->(message) { warn "[benchmark] #{message}" }
    ).call

    valid_heartbeat_rows = results.find { |result| result.cohort == "global" }&.heartbeat_count
    copied_heartbeat_rows = ENV.fetch("BENCHMARK_COPIED_HEARTBEAT_ROWS", valid_heartbeat_rows).to_i
    rebuilds = JSON.parse(ENV.fetch("BENCHMARK_REBUILDS_JSON", "[]"), symbolize_names: true)
    metadata = {
      generated_at: Time.current.utc.iso8601,
      commit: `git rev-parse --short HEAD`.strip,
      database: Clickhouse::Record.connection_db_config.database,
      iterations:, project_iterations:,
      clickhouse_version: Clickhouse::Record.connection.select_value("SELECT version()"),
      database_size: Clickhouse::Record.connection.select_value(<<~SQL.squish),
        SELECT formatReadableSize(sum(bytes_on_disk))
        FROM system.parts
        WHERE active AND database = currentDatabase()
      SQL
      machine: ENV.fetch("BENCHMARK_MACHINE", RUBY_PLATFORM),
      container_runtime: ENV.fetch("BENCHMARK_CONTAINER_RUNTIME", "Docker Compose"),
      copied_heartbeat_rows:, valid_heartbeat_rows:,
      excluded_invalid_rows: copied_heartbeat_rows - valid_heartbeat_rows.to_i,
      rebuilds:,
      largest_rebuild_seconds: rebuilds.pluck(:seconds).compact.max || "not recorded",
      largest_rebuild_peak_memory: ENV.fetch("BENCHMARK_REBUILD_PEAK_MEMORY", "not recorded")
    }
    public_results = results.map(&:to_h)
    unless ActiveModel::Type::Boolean.new.cast(ENV.fetch("BENCHMARK_INCLUDE_IDENTIFIERS", false))
      public_results = public_results.map do |result|
        result = result.merge(source_user_id: nil)
        if result[:project].present?
          token = Digest::SHA256.hexdigest([ result[:cohort], result[:project] ].join("\0")).first(10)
          result[:project] = "project-#{token}"
        end
        if result[:filter_value].present? && %w[project machine].include?(result[:filter_dimension])
          token = Digest::SHA256.hexdigest([ result[:filter_dimension], result[:filter_value] ].join("\0")).first(10)
          result[:filter_value] = "#{result[:filter_dimension]}-#{token}"
        end
        result
      end
    end
    payload = { metadata:, results: public_results }
    results_path = Rails.root.join(ENV.fetch("RESULTS_PATH", "public/ch-comprehensive-benchmark-results.json"))
    report_path = Rails.root.join(ENV.fetch("REPORT_PATH", "public/ch-comprehensive-benchmark-report.html"))

    File.write(results_path, JSON.pretty_generate(payload))
    File.write(report_path, ClickhouseBenchmarkReport.new(results: public_results, metadata:).render)

    puts "Wrote #{results.length} benchmark cases to #{results_path}"
    puts "Wrote report to #{report_path}"
  end
end
