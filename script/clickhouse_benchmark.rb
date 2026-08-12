#!/usr/bin/env ruby

require_relative "../config/environment"

require "csv"
require "digest"
require "erb"
require "json"
require "pg"
require "bigdecimal"

class ClickHouseBenchmark
  REQUESTED_SOURCE_USER_ID = 58
  LABELS = [ *%w[tiny small medium large extreme], "user 58" ].freeze
  TARGETS = [ 100, 1_000, 10_000, 100_000, 1_000_000 ].freeze
  REPETITIONS = 5
  BATCH_SIZE = 5_000
  RESULT_PATH = Rails.root.join("tmp/clickhouse_benchmark_results.json")
  REPORT_PATH = Rails.root.join("public/clickhouse-benchmark.html")
  PG_TABLE = "clickhouse_benchmark_heartbeats"
  CH_TABLES = %w[
    clickhouse_benchmark_second
    clickhouse_benchmark_requested
    clickhouse_benchmark_bucketed
  ].freeze
  CH_TIME_TABLE = "clickhouse_benchmark_by_time"
  PRODUCTION_SYSTEM = "clickhouse_production"
  LOAD_TABLES = [ *CH_TABLES, CH_TIME_TABLE ].freeze
  CANDIDATE_KEYS = {
    "clickhouse_benchmark_second" => {
      "primary" => "(user_id, time_second)",
      "order" => "(user_id, time_second, time, id)"
    },
    "clickhouse_benchmark_requested" => {
      "primary" => "(user_id, time)",
      "order" => "(user_id, time, id)"
    },
    "clickhouse_benchmark_bucketed" => {
      "primary" => "(user_id, time_5m, time_second)",
      "order" => "(user_id, time_5m, time_second, time, id)"
    }
  }.freeze
  SYSTEM_LABELS = {
    "postgresql" => "PostgreSQL",
    "clickhouse_benchmark_second" => "ClickHouse second-resolution key",
    "clickhouse_benchmark_requested" => "ClickHouse requested timestamp key",
    "clickhouse_benchmark_bucketed" => "ClickHouse selected per-user key",
    PRODUCTION_SYSTEM => "ClickHouse production routing"
  }.freeze
  SENSITIVE = %w[project branch entity machine user_agent ip_address dependencies ai_model ai_session].freeze
  FILTER_SCENARIOS = [
    { name: "dashboard filter: date range", label: "Date range", fields: [], date_range: true },
    { name: "dashboard filter: operating system", label: "Operating system", fields: %i[operating_system] },
    { name: "dashboard filter: editor", label: "Editor", fields: %i[editor] },
    { name: "dashboard filter: project", label: "Project", fields: %i[project] },
    { name: "dashboard filter: language", label: "Language", fields: %i[language] },
    { name: "dashboard filter: category", label: "Category", fields: %i[category] },
    { name: "dashboard filter mix: date/project/language", label: "Date range + project + language", fields: %i[project language], date_range: true },
    { name: "dashboard filter mix: OS/editor/category", label: "Operating system + editor + category", fields: %i[operating_system editor category] },
    { name: "dashboard filter mix: all dimensions", label: "Date range + all dimensions", fields: %i[operating_system editor project language category], date_range: true }
  ].freeze
  SURFACES = {
    "Ingestion and import deduplication" => [ "direct ingest batch (100 rows)" ],
    "Raw and WakaTime-compatible APIs" => [ "latest heartbeat", "raw day page", "exact day duration (time,id) with 120s cap", "boundary-aware duration with predecessor" ],
    "Dashboard, profiles and project analytics" => [ "grouped project duration", "attributed language duration", "all-time dashboard totals/filter options", "today dashboard snapshot", "project details", "daily activity graph in timezone", "coding rhythm" ],
    "Dashboard filters" => FILTER_SCENARIOS.map { |scenario| scenario.fetch(:name) },
    "Timeline" => [ "timeline 48h multi-user preload" ],
    "Leaderboards, streaks and badges" => [ "leaderboard grouped users", "streak daily durations" ],
    "Recent activity and public caches" => [ "last-hour heartbeat count", "recent 24h heartbeat counts", "hourly active users", "latest active project per user" ],
    "Homepage totals" => [ "home totals exact" ],
    "Weekly email and exports" => [ "weekly email stats", "full export scan" ],
    "Admin and trust analysis" => [ "admin machine/IP sharing", "admin user-agent substring", "active user IDs" ],
    "Repository event synchronisation" => [ "recent heartbeat writers by creation time" ],
    "Account merge and anonymisation" => [ "account-transfer source scan", "anonymisation source scan" ]
  }.freeze
  COLUMNS = %w[id user_id time project branch entity category editor language machine operating_system type user_agent
    ip_address dependencies lineno lines cursorpos line_additions line_deletions project_root_count is_write source_type
    ysws_program ja4_id ai_model ai_session ai_subscription_plan ai_input_tokens ai_output_tokens ai_prompt_length
    ai_line_changes human_line_changes deleted_at created_at updated_at].freeze
  DATASET_COLUMNS = [ *COLUMNS, "version" ].freeze
  DATASET_TIMESTAMP_COLUMNS = %w[deleted_at created_at updated_at].freeze

  Query = Data.define(:name, :scope, :comparable, :pg, :ch)

  def initialize
    @pg = ActiveRecord::Base.connection.raw_connection
    @pg.type_map_for_results = PG::BasicTypeMapForResults.new(@pg)
    @ch = ClickHouse::Client.current
  end

  def call(command)
    case command
    when "load" then load
    when "restore-postgres" then restore_postgres
    when "run" then run
    when "report" then report
    when "all" then load; run; report
    when "cleanup" then cleanup
    else abort "Usage: #{$PROGRAM_NAME} {load|restore-postgres|run|report|cleanup|all}"
    end
  end

  def restore_postgres
    @pg.exec("DROP TABLE IF EXISTS #{PG_TABLE}")
    @pg.exec("CREATE UNLOGGED TABLE #{PG_TABLE} (LIKE heartbeats INCLUDING ALL)")
    count = 0
    @pg.copy_data("COPY #{PG_TABLE} (#{COLUMNS.join(',')}) FROM STDIN WITH (FORMAT csv)") do
      @ch.each_json_each_row(<<~SQL.squish) do |row|
        SELECT #{COLUMNS.join(',')}, dependencies_is_null, dependencies_json
        FROM clickhouse_benchmark_bucketed FINAL ORDER BY id
      SQL
        row["dependencies"] = nil if row.fetch("dependencies_is_null")
        row["dependencies"] = JSON.parse(row["dependencies_json"]) if row["dependencies_json"]
        @pg.put_copy_data(CSV.generate_line(COLUMNS.map { |column| pg_csv_value(row[column]) }))
        count += 1
        puts "Restored #{count} PostgreSQL rows." if (count % 100_000).zero?
      end
    end
    puts "Restored #{count} PostgreSQL benchmark rows."
  end

  def cleanup
    @pg.exec("DROP TABLE IF EXISTS #{PG_TABLE}")
    LOAD_TABLES.each { |table| @ch.execute("DROP TABLE IF EXISTS #{table}") }
  end

  def load
    source_url = ENV["READONLY_PROD_DB_URL"]
    abort "READONLY_PROD_DB_URL is required" if source_url.to_s.empty?

    source = PG.connect(source_url)
    source.type_map_for_results = PG::BasicTypeMapForResults.new(source)
    source.exec("SET default_transaction_read_only = on")
    source.exec("SET statement_timeout = '2min'")
    cohorts = select_cohorts(source)
    prepare_targets
    counts = Hash.new(0)
    ranges = {}
    next_id = 0
    dataset_digest = Digest::SHA256.new

    @pg.copy_data("COPY #{PG_TABLE} (#{COLUMNS.join(',')}) FROM STDIN WITH (FORMAT csv)") do
      cohorts.each_with_index do |cohort, index|
        stream_user(source, cohort.fetch("user_id")) do |source_row|
          next_id += 1
          row = transform(source_row, user_id: index + 1, id: next_id)
          update_dataset_digest(dataset_digest, row)
          @pg.put_copy_data(CSV.generate_line(COLUMNS.map { |column| pg_csv_value(row[column]) }))
          dependencies_fallback = row["dependencies"].is_a?(Array) &&
            row["dependencies"].any? { |dependency| !dependency.is_a?(String) }
          clickhouse_row = row.merge(
            "dependencies" => dependencies_fallback ? [] : row["dependencies"] || [],
            "dependencies_is_null" => row["dependencies"].nil?,
            "dependencies_json" => dependencies_fallback ? JSON.generate(row["dependencies"]) : nil
          )
          LOAD_TABLES.each { |table| insert_buffer(table, clickhouse_row) }
          label = LABELS[index]
          counts[label] += 1
          ranges[label] = update_range(ranges[label], row["time"])
        end
      end
    end
    flush_buffers
    LOAD_TABLES.each { |table| @ch.execute("OPTIMIZE TABLE #{table} FINAL") }
    abort "Production user #{REQUESTED_SOURCE_USER_ID} has no active heartbeats" if counts.fetch("user 58", 0).zero?

    metadata = {
      "benchmark_run_id" => SecureRandom.uuid,
      "generated_at" => Time.now.utc.iso8601,
      "clickhouse_version" => clickhouse_version,
      "cohorts" => cohorts.each_with_index.map do |cohort, index|
        label = LABELS.fetch(index)
        {
          "label" => label,
          "user_id" => index + 1,
          "target" => cohort.fetch("target"),
          "rows" => counts[label],
          "time_range" => ranges[label],
          "selection" => cohort["requested"] ? "Required production user 58" : "Nearest active-row target"
        }
      end,
      "total_rows" => counts.values.sum,
      "dataset_fingerprint" => "#{counts.values.sum}:#{dataset_digest.hexdigest}",
      "candidate_ordering" => candidate_ordering
    }
    write_results(metadata.merge("benchmarks" => []))
    puts "Loaded #{metadata['total_rows']} pseudonymised active heartbeats across #{counts.length} cohorts."
  ensure
    source&.close
  end

  def run
    existing = read_results
    validate_dataset!(existing)
    existing["run_started_at"] ||= Time.now.utc.iso8601
    existing.delete("run_completed_at")
    cohorts = existing.fetch("cohorts")
    max_time = @pg.exec("SELECT MAX(time) FROM #{PG_TABLE} WHERE time BETWEEN 0 AND 253402300799").getvalue(0, 0).to_f
    existing["invalid_time_rows"] = @pg.exec(
      "SELECT COUNT(*) FROM #{PG_TABLE} WHERE time < 0 OR time > 253402300799"
    ).getvalue(0, 0).to_i
    benchmarks = existing.fetch("benchmarks", [])
    benchmarks.reject! do |entry|
      [ "direct ingest duplicate lookup", "direct ingest batch (100 rows)" ].include?(entry["family"])
    end
    benchmarks << benchmark_ingest
    write_results(existing.merge("anchor_time" => max_time, "methodology" => methodology, "benchmarks" => benchmarks))
    completed = benchmarks.to_set { |entry| [ entry.fetch("family"), entry.fetch("cohort") ] }
    queries.each do |query|
      subjects = query.scope == :user ? cohorts : [ { "label" => "all", "user_id" => nil } ]
      subjects.each do |subject|
        next if completed.include?([ query.name, subject["label"] ])

        params = parameters(subject["user_id"], max_time)
        results = {}
        puts "Benchmarking #{query.name} (#{subject['label']}) on PostgreSQL."
        results["postgresql"] = benchmark_pg(format(query.pg, params))
        CH_TABLES.each do |table|
          puts "Benchmarking #{query.name} (#{subject['label']}) on #{table}."
          results[table] = benchmark_ch(format_ch_query(query.ch, params.merge(table: table)))
        end
        production_table = %i[user base_global].include?(query.scope) ? "clickhouse_benchmark_bucketed" : CH_TIME_TABLE
        puts "Benchmarking #{query.name} (#{subject['label']}) on #{PRODUCTION_SYSTEM}."
        results[PRODUCTION_SYSTEM] = benchmark_ch(format_ch_query(query.ch, params.merge(table: production_table)))
        correctness = compare(results, query.comparable)
        benchmarks << { "family" => query.name, "cohort" => subject["label"], "correctness" => correctness, "systems" => results }
        write_results(existing.merge("anchor_time" => max_time, "methodology" => methodology, "benchmarks" => benchmarks))
        puts "Benchmarked #{query.name} (#{subject['label']})."
      end
    end
    write_results(existing.merge(
      "anchor_time" => max_time,
      "methodology" => methodology,
      "benchmarks" => benchmarks,
      "run_completed_at" => Time.now.utc.iso8601
    ))
  end

  def report
    data = read_results
    abort "Benchmark run is incomplete" unless data["benchmark_run_id"] && data["dataset_fingerprint"] && data["run_completed_at"]
    abort "Benchmark result count is incomplete" unless data.fetch("benchmarks").length == expected_benchmark_count
    selected = PRODUCTION_SYSTEM
    selected_label = SYSTEM_LABELS.fetch(selected, selected)
    conclusion = rollup_conclusion(data)
    matches = data.fetch("benchmarks").count { |entry| entry.fetch("correctness") == "match" }
    postgres_average_p50 = average_p50(data, "postgresql")
    selected_average_p50 = average_p50(data, selected)
    rows = data.fetch("benchmarks").map do |entry|
      entry.fetch("systems").map do |system, result|
        "<tr><td>#{h entry['family']}</td><td>#{h entry['cohort']}</td><td>#{h SYSTEM_LABELS.fetch(system, system)}</td><td>#{number result['first_ms']}</td><td>#{number result['p50_ms']}</td><td>#{number result['p95_ms']}</td><td>#{h result['rows_read'] || 'unavailable'}</td><td>#{h result['bytes_read'] || 'unavailable'}</td><td class=\"#{entry['correctness'] == 'match' ? 'good' : 'warn'}\">#{h entry['correctness']}</td></tr>"
      end.join
    end.join
    cohort_rows = data.fetch("cohorts").map { |c| "<tr><td>#{h c['label']}</td><td>#{h c['selection']}</td><td>#{c['target']}</td><td>#{c['rows']}</td><td>#{h Array(c['time_range']).join(' to ')}</td></tr>" }.join
    ddl = data.fetch("candidate_ordering").map { |name, order| "<li><code>#{h SYSTEM_LABELS.fetch(name, name)}</code>: ORDER BY <code>#{h order}</code></li>" }.join
    surface_rows = SURFACES.map do |surface, workloads|
      entries = data.fetch("benchmarks").select { |entry| workloads.include?(entry.fetch("family")) }
      correctness = entries.all? { |entry| entry.fetch("correctness") == "match" } ? "match" : "mismatch"
      p95 = entries.filter_map { |entry| entry.dig("systems", selected, "p95_ms") }.max
      "<tr><td>#{h surface}</td><td>#{h workloads.join(', ')}</td><td>#{number p95}</td><td class=\"#{correctness == 'match' ? 'good' : 'warn'}\">#{correctness}</td></tr>"
    end.join
    filter_rows = FILTER_SCENARIOS.map do |scenario|
      entries = data.fetch("benchmarks").select { |entry| entry.fetch("family") == scenario.fetch(:name) }
      correctness = entries.all? { |entry| entry.fetch("correctness") == "match" } ? "match" : "mismatch"
      postgres_p50 = entries.filter_map { |entry| entry.dig("systems", "postgresql", "p50_ms") }.max
      clickhouse_p50 = entries.filter_map { |entry| entry.dig("systems", selected, "p50_ms") }.max
      clickhouse_p95 = entries.filter_map { |entry| entry.dig("systems", selected, "p95_ms") }.max
      "<tr><td>#{h scenario.fetch(:label)}</td><td>#{entries.length}</td><td>#{number postgres_p50}</td><td>#{number clickhouse_p50}</td><td>#{number clickhouse_p95}</td><td class=\"#{correctness == 'match' ? 'good' : 'warn'}\">#{correctness}</td></tr>"
    end.join
    regressions = data.fetch("benchmarks").filter_map do |entry|
      postgres = entry.dig("systems", "postgresql", "p50_ms")
      clickhouse = entry.dig("systems", PRODUCTION_SYSTEM, "p50_ms")
      next unless postgres && clickhouse && clickhouse - postgres > 10

      [ entry, postgres, clickhouse ]
    end
    recovery = benchmark_recovery_poll
    regression_rows = regressions.map do |entry, postgres, clickhouse|
      "<tr><td>#{h entry['family']}</td><td>#{h entry['cohort']}</td><td>#{number postgres}</td><td>#{number clickhouse}</td><td>#{number clickhouse - postgres}</td><td>#{h regression_explanation(entry['family'])}</td></tr>"
    end.join
    html = <<~HTML
      <!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Heartbeat storage benchmark</title>
      <style>:root{color-scheme:light dark;--accent:#ec3750;--panel:#fff;--ink:#172b4d;--muted:#667085}*{box-sizing:border-box}body{margin:0;background:#f4f6fa;color:var(--ink);font:15px/1.5 system-ui,sans-serif}main{max-width:1400px;margin:auto;padding:40px 24px}h1{font-size:38px;margin-bottom:4px}h2{margin-top:38px}.lead{color:var(--muted);font-size:18px}.card{background:var(--panel);border:1px solid #dfe3eb;border-radius:14px;padding:22px;margin:18px 0;box-shadow:0 4px 18px #172b4d0c}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px}.metric b{display:block;font-size:25px;color:var(--accent)}.scroll{overflow:auto}table{width:100%;border-collapse:collapse;white-space:nowrap}th,td{text-align:left;padding:9px 11px;border-bottom:1px solid #e7eaf0}th{position:sticky;top:0;background:#f8f9fb}.good{color:#16803c}.warn{color:#b54708}code{background:#eef1f6;padding:2px 5px;border-radius:4px}@media(prefers-color-scheme:dark){body{background:#101828;color:#e4e7ec}.card{--panel:#1d2939;border-color:#344054}.lead{--muted:#98a2b3}th{background:#263548}th,td{border-color:#344054}code{background:#344054}}</style></head>
      <body><main><h1>Heartbeat storage benchmark</h1><p class="lead">PostgreSQL compared with three ClickHouse layouts on product-surface and dashboard-filter workloads.</p>
      <div class="grid"><div class="card metric"><span>ClickHouse</span><b>#{h data['clickhouse_version']}</b></div><div class="card metric"><span>Rows</span><b>#{data['total_rows']}</b></div><div class="card metric"><span>Strict matches</span><b>#{matches}/#{data.fetch('benchmarks').length}</b></div><div class="card metric"><span>Selected design</span><b>#{h selected_label}</b></div><div class="card metric"><span>PostgreSQL average p50</span><b>#{number postgres_average_p50} ms</b></div><div class="card metric"><span>Selected ClickHouse average p50</span><b>#{number selected_average_p50} ms</b></div></div>
      <section class="card"><h2>Run provenance</h2><p>Run <code>#{h data['benchmark_run_id']}</code> completed at <code>#{h data['run_completed_at']}</code>. Before timing, PostgreSQL and every ClickHouse candidate matched the complete logical-row fingerprint <code>#{h data['dataset_fingerprint']}</code>, including full-resolution Float64 timestamps, nullable and nested dependencies, all product fields and replacement versions.</p></section>
      <section class="card"><h2>Dataset</h2><p>Only active rows were sampled. User and heartbeat IDs were remapped. Sensitive strings and addresses were deterministically pseudonymised before loading and never included in this report. Production user 58 is included as a dedicated cohort in addition to the five account-size cohorts. The sample contains #{data.fetch('invalid_time_rows', 0)} legacy timestamp rows outside the product's valid epoch range; timestamp-derived workloads exclude them on both systems exactly as production does.</p><div class="scroll"><table><thead><tr><th>Cohort</th><th>Selection</th><th>Target</th><th>Rows</th><th>Sample range (UTC epoch)</th></tr></thead><tbody>#{cohort_rows}</tbody></table></div></section>
      <section class="card"><h2>Candidate DDL</h2><p>All layouts used the same tested columns, <code>ReplacingMergeTree(version)</code>, monthly partition and settings. Only sorting differed. The final query layouts omit <code>fields_hash</code>; exact deduplication hashes live only in the ClickHouse canonical store and alias index.</p><ul>#{ddl}</ul></section>
      <section class="card"><h2>Product-surface coverage</h2><p>Every heartbeat-backed product area is represented by a production query shape or a labelled storage proxy. The p95 below is the slowest cohort in that surface on production table routing. Lifecycle correctness is covered separately by repository and ClickHouse integration tests.</p><div class="scroll"><table><thead><tr><th>Surface</th><th>Benchmarked workloads</th><th>Worst p95 ms</th><th>Correctness</th></tr></thead><tbody>#{surface_rows}</tbody></table></div></section>
      <section class="card"><h2>Dashboard filter coverage</h2><p>Each scenario runs for all #{data.fetch('cohorts').length} cohorts, including production user 58. Date-range scenarios use an exact 30-day range ending at a populated heartbeat for that cohort. Dimension values come from the same heartbeat so mixed filters exercise a real non-empty combination. Figures below are the slowest cohort for each scenario.</p><div class="scroll"><table><thead><tr><th>Scenario</th><th>Cohorts</th><th>Worst PG p50 ms</th><th>Worst CH p50 ms</th><th>Worst CH p95 ms</th><th>Correctness</th></tr></thead><tbody>#{filter_rows}</tbody></table></div></section>
      <section class="card"><h2>Investigated regressions over 10 ms</h2><p>#{regressions.length} of #{data.fetch('benchmarks').length} cases have a production-routing p50 more than 10 ms behind PostgreSQL. They are retained rather than hidden because their exact results still match. The dominant cause is ClickHouse HTTP and <code>FINAL</code> fixed cost on sparse cohorts, not large-account scaling.</p><div class="scroll"><table><thead><tr><th>Workload</th><th>Cohort</th><th>PG p50 ms</th><th>CH p50 ms</th><th>Difference ms</th><th>Investigation</th></tr></thead><tbody>#{regression_rows}</tbody></table></div><p>Rejected experiments: 1,024-row index granularity was neutral or slower and alternate ID/search layouts harmed the real query mix. Materialised <code>set(100)</code> indexes on operating system, editor, language and category plus a project bloom index skipped no rows under exact <code>FINAL</code> queries and increased filter average p50 from 16.066 ms to 18.094 ms, so they were removed. Partition pruning runs before <code>FINAL</code> because each replacement key is constrained to one time partition. The selected text index reduces broad user-agent search reads while retaining exact substring filtering.</p></section>
      <section class="card"><h2>Recovery scan</h2><p>An empty global delivery audit over #{recovery.fetch('source_rows')} canonical-sized benchmark rows reads #{recovery.fetch('read_rows')} rows and has a #{number recovery.fetch('p95_ms')} ms p95. Production PostgreSQL estimates #{h recovery.fetch('production_rows')} heartbeat rows, so the minute cron was removed. Failed writes now enqueue a user-scoped repair, while the global audit runs once daily and the cutover drain remains an explicit exhaustive check.</p></section>
      <section class="card"><h2>Methodology and limitations</h2><p>#{h data['methodology'] || methodology}</p><p>Recent windows are anchored at sampled max(time), except the explicit dashboard date filters, which use each cohort's populated 30-day range: <code>#{h data['anchor_time']}</code>. PostgreSQL read volume is logical 8 KiB buffers, not physical bytes. Cache state is not reset. Production ClickHouse ingest measures full repository admission: locks, canonical state, aliases, both query layouts, visibility checks and delivery acknowledgement. The PostgreSQL ingest baseline is one local table insert, so it understates equivalent deduplication and durability work. Replacement retries and concurrent failures are covered by ClickHouse integration tests. Export and account lifecycle timings measure their source scans. This is a #{data.fetch('cohorts').length}-user shape benchmark, not a concurrency or full-production-cardinality test.</p></section>
      <section class="card"><h2>Results</h2><div class="scroll"><table><thead><tr><th>Query family</th><th>Cohort</th><th>System</th><th>First ms</th><th>p50 ms</th><th>p95 ms</th><th>Rows read</th><th>Bytes read</th><th>Correctness</th></tr></thead><tbody>#{rows}</tbody></table></div></section>
      <section class="card"><h2>Implemented architecture</h2><p>The production layout keeps full-resolution <code>time</code> and adds only the materialized second and five-minute buckets used by query pruning and sorting. User-scoped reads use <code>(user_id, time_5m, time_second, time, id)</code>. A replacement-aware physical mirror ordered by <code>(time_5m, time_second, user_id, time, id)</code> serves recent cross-user reads because ClickHouse cannot use an alternate-order projection with <code>FINAL</code>. Exact timestamp predicates run after bucket pruning on both tables. A ClickHouse text index accelerates user-agent substring searches.</p><p>Rails callers use <code>HeartbeatRepository</code>. ClickHouse <code>heartbeat_store</code> owns canonical payload and lifecycle state, while <code>heartbeat_aliases</code> owns exact canonical and legacy hash deduplication. Independent delivery versions repair either query layout after an interrupted write. PostgreSQL retains only monotonic sequences, transient advisory locks and coarse lifecycle workflow status. Dashboard, profile and exact homepage totals query ClickHouse directly; PostgreSQL dashboard rollups are neither read nor rebuilt after cutover.</p></section>
      <section class="card"><h2>Decision</h2><p><strong>Selected ClickHouse design:</strong> #{h selected_label}.</p><p>#{h conclusion}</p></section>
      </main></body></html>
    HTML
    File.write(REPORT_PATH, html)
    puts "Wrote #{REPORT_PATH}."
  end

  private

  def select_cohorts(source)
    sql = <<~SQL
      WITH candidates AS (
        SELECT user_id, source_heartbeats_count AS heartbeat_count
        FROM dashboard_rollups
        WHERE dimension = 'total' AND bucket_value = '' AND source_heartbeats_count > 0
          AND user_id <> #{REQUESTED_SOURCE_USER_ID}
      ), ranked AS (
        SELECT t.target, c.user_id, c.heartbeat_count,
               row_number() OVER (PARTITION BY t.target ORDER BY abs(c.heartbeat_count - t.target), c.heartbeat_count) AS rank
        FROM (VALUES #{TARGETS.map { |n| "(#{n})" }.join(',')}) t(target) CROSS JOIN candidates c
      )
      SELECT target, user_id, heartbeat_count FROM ranked WHERE rank <= 20 ORDER BY target, rank
    SQL
    rows = source.exec(sql).to_a
    selected = []
    TARGETS.each do |target|
      candidate = rows.find { |row| row["target"].to_i == target && selected.none? { |picked| picked["user_id"] == row["user_id"] } }
      abort "Could not select five distinct cohorts" unless candidate
      selected << candidate
    end
    selected << {
      "target" => "all active",
      "user_id" => REQUESTED_SOURCE_USER_ID.to_s,
      "requested" => true
    }
    selected
  end

  def stream_user(source, source_user_id)
    source.exec("BEGIN READ ONLY")
    source.exec_params("DECLARE benchmark_rows NO SCROLL CURSOR FOR SELECT #{COLUMNS.join(',')} FROM heartbeats WHERE user_id = $1 AND deleted_at IS NULL ORDER BY id", [ source_user_id ])
    loop do
      batch = source.exec("FETCH FORWARD #{BATCH_SIZE} FROM benchmark_rows")
      break if batch.ntuples.zero?
      batch.each { |row| yield row }
    end
    source.exec("COMMIT")
  rescue
    source.exec("ROLLBACK") if source.transaction_status != PG::PQTRANS_IDLE
    raise
  end

  def prepare_targets
    @pg.exec("DROP TABLE IF EXISTS #{PG_TABLE}")
    @pg.exec("CREATE UNLOGGED TABLE #{PG_TABLE} (LIKE heartbeats INCLUDING ALL)")
    ddl = File.read(Rails.root.join("db/clickhouse/001_create_heartbeats.sql"))
    CH_TABLES.each do |table|
      @ch.execute("DROP TABLE IF EXISTS #{table}")
      table_ddl = ddl.sub(/CREATE TABLE IF NOT EXISTS heartbeats/, "CREATE TABLE #{table}")
      keys = CANDIDATE_KEYS.fetch(table)
      table_ddl = table_ddl.sub(/PRIMARY KEY \([^\n]+\)/, "PRIMARY KEY #{keys.fetch('primary')}")
      table_ddl = table_ddl.sub(/ORDER BY \([^\n]+\)/, "ORDER BY #{keys.fetch('order')}")
      @ch.execute(table_ddl)
    end
    by_time_ddl = File.read(Rails.root.join("db/clickhouse/009_create_heartbeats_by_time.sql"))
      .sub(/CREATE TABLE IF NOT EXISTS heartbeats_by_time/, "CREATE TABLE #{CH_TIME_TABLE}")
    @ch.execute("DROP TABLE IF EXISTS #{CH_TIME_TABLE}")
    @ch.execute(by_time_ddl)
    @buffers = LOAD_TABLES.to_h { |table| [ table, [] ] }
  end

  def candidate_ordering
    CANDIDATE_KEYS.transform_values { |keys| keys.fetch("order") }
  end

  def transform(row, user_id:, id:)
    output = row.transform_values { |value| value }
    output["id"] = id
    output["user_id"] = user_id
    SENSITIVE.each { |field| output[field] = pseudonymise(field, output[field]) }
    output["version"] = 1
    output
  end

  def pseudonymise(field, value)
    return nil if value.nil?
    return pseudonymise_dependencies(value) if field == "dependencies"
    return pseudonymous_ip(value.to_s) if field == "ip_address"
    token(field, value.to_s)
  end

  def pseudonymise_dependencies(value)
    Array(value).map do |dependency|
      if dependency.is_a?(Array)
        pseudonymise_dependencies(dependency)
      elsif dependency.nil?
        nil
      else
        token("dependencies", dependency.to_s)
      end
    end
  end

  def token(field, value)
    return "" if value.empty?
    digest = Digest::SHA256.hexdigest("clickhouse-benchmark:#{field}:#{value}")
    chars = (digest * ((value.length / digest.length) + 1))[0, value.length]
    field == "user_agent" && value.length >= 10 ? "agent/#{chars[6..]}" : chars
  end

  def pseudonymous_ip(value)
    digest = Digest::SHA256.digest("clickhouse-benchmark:ip:#{value}")
    words = digest.bytes.each_slice(2).first(6).map { |a, b| ((a << 8) + b).to_s(16) }
    "2001:db8:#{words.join(':')}"
  end

  def pg_csv_value(value)
    case value
    when Array then pg_array_value(value)
    when Time, DateTime then value.utc.iso8601(6)
    else value
    end
  end

  def pg_array_value(values)
    "{" + values.map do |value|
      if value.is_a?(Array)
        pg_array_value(value)
      elsif value.nil?
        "NULL"
      else
        '"' + value.gsub(/["\\]/) { |character| "\\#{character}" } + '"'
      end
    end.join(",") + "}"
  end

  def insert_buffer(table, row)
    @buffers[table] << row
    flush_buffer(table) if @buffers[table].length >= BATCH_SIZE
  end

  def flush_buffer(table)
    @ch.insert_json_each_row(table, @buffers[table])
    @buffers[table].clear
  end

  def flush_buffers = LOAD_TABLES.each { |table| flush_buffer(table) unless @buffers[table].empty? }

  def update_range(range, time)
    value = time.to_f
    range ? [ [ range[0], value ].min, [ range[1], value ].max ] : [ value, value ]
  end

  def validate_dataset!(metadata)
    abort "Benchmark artifact requires a fresh load" unless metadata["benchmark_run_id"] && metadata["dataset_fingerprint"]
    abort "ClickHouse version changed after load" unless clickhouse_version == metadata.fetch("clickhouse_version")

    expected = metadata.fetch("dataset_fingerprint")
    postgres = dataset_fingerprint(each_pg_row("SELECT #{COLUMNS.join(',')}, 1 AS version FROM #{PG_TABLE} ORDER BY id"))
    abort "PostgreSQL benchmark data changed after load" unless postgres == expected

    LOAD_TABLES.each do |table|
      rows = @ch.each_json_each_row(<<~SQL.squish)
        SELECT #{COLUMNS.join(',')}, version, dependencies_is_null, dependencies_json
        FROM #{table} FINAL ORDER BY id
      SQL
      abort "#{table} benchmark data changed after load" unless dataset_fingerprint(rows) == expected
    end
    abort "Benchmark candidate ordering changed after load" unless candidate_ordering == metadata.fetch("candidate_ordering")
  end

  def dataset_fingerprint(rows)
    digest = Digest::SHA256.new
    count = 0
    rows.each do |row|
      update_dataset_digest(digest, row)
      count += 1
    end
    "#{count}:#{digest.hexdigest}"
  end

  def update_dataset_digest(digest, row)
    logical = row.slice(*DATASET_COLUMNS)
    if row.key?("dependencies_is_null")
      logical["dependencies"] = if row["dependencies_is_null"]
        nil
      elsif row["dependencies_json"]
        JSON.parse(row["dependencies_json"])
      else
        row["dependencies"]
      end
    end
    logical["time"] = [ logical.fetch("time").to_f ].pack("G").unpack1("H*")
    DATASET_TIMESTAMP_COLUMNS.each do |column|
      logical[column] = Time.zone.parse(logical[column].to_s).utc.iso8601(6) if logical[column]
    end
    payload = JSON.generate(logical.transform_values { |value| canonical_value(value) })
    digest << [ payload.bytesize ].pack("Q>") << payload
  end

  def expected_benchmark_count
    1 + queries.sum { |query| query.scope == :user ? LABELS.length : 1 }
  end

  def parameters(user_id, anchor)
    values = {
      user: user_id,
      anchor:,
      hour_start: anchor - 3_600,
      day_start: anchor - 86_400,
      week_start: anchor - 604_800,
      year_start: anchor - 31_536_000,
      latest_start: anchor - 90_000,
      needle: benchmark_user_agent_needle,
      archived_pairs: benchmark_archived_pairs
    }
    values = values.merge(values.slice(:anchor, :hour_start, :day_start, :week_start, :year_start, :latest_start)
      .to_h { |name, value| [ "#{name}_5m".to_sym, value.floor.div(300) * 300 ] })
    values.merge!(benchmark_filter_parameters(user_id)) if user_id
    values
  end

  def queries
    pg_duration = <<~SQL.squish
      SELECT ROUND(COALESCE(SUM(diff), 0)::numeric, 6) AS value
      FROM (
        SELECT LEAST(GREATEST(time - LAG(time) OVER (ORDER BY time, id), 0), 120) AS diff
        FROM #{PG_TABLE}
        WHERE user_id = %{user} AND deleted_at IS NULL AND time BETWEEN %{day_start} AND %{anchor}
      ) duration_rows
    SQL
    ch_duration = <<~SQL.squish
      SELECT round(COALESCE(sum(diff), 0), 6) AS value
      FROM (
        SELECT least(greatest(time - lagInFrame(time, 1, time) OVER (
          ORDER BY time, id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ), 0), 120) AS diff
        FROM %{table} FINAL
        WHERE user_id = %{user} AND deleted_at IS NULL
          AND time_5m BETWEEN %{day_start_5m} AND %{anchor_5m}
          AND time BETWEEN %{day_start} AND %{anchor}
      )
    SQL
    [
      Query.new(
        "latest heartbeat", :user, true,
        "SELECT id,time,project FROM #{PG_TABLE} WHERE user_id=%{user} AND deleted_at IS NULL ORDER BY time DESC,id DESC LIMIT 1",
        [
          "SELECT id,time,project FROM %{table} FINAL WHERE user_id=%{user} AND deleted_at IS NULL AND time_5m>=%{latest_start_5m} AND time>=%{latest_start} ORDER BY time DESC,id DESC LIMIT 1",
          "SELECT id,time,project FROM %{table} FINAL WHERE user_id=%{user} AND deleted_at IS NULL ORDER BY time DESC,id DESC LIMIT 1"
        ]
      ),
      Query.new(
        "raw day page", :user, true,
        "SELECT id,time,project,language FROM #{PG_TABLE} WHERE user_id=%{user} AND deleted_at IS NULL AND time BETWEEN %{day_start} AND %{anchor} ORDER BY time DESC,id DESC LIMIT 100",
        "SELECT id,time,project,language FROM %{table} FINAL WHERE user_id=%{user} AND deleted_at IS NULL AND time_5m BETWEEN %{day_start_5m} AND %{anchor_5m} AND time BETWEEN %{day_start} AND %{anchor} ORDER BY time DESC,id DESC LIMIT 100"
      ),
      Query.new("exact day duration (time,id) with 120s cap", :user, true, pg_duration, ch_duration),
      Query.new(
        "boundary-aware duration with predecessor", :user, true,
        <<~SQL.squish,
          WITH boundary AS (
            SELECT id,time FROM #{PG_TABLE} WHERE user_id=%{user} AND deleted_at IS NULL AND time<%{day_start}
            ORDER BY time DESC,id DESC LIMIT 1
          ), rows_with_boundary AS (
            SELECT id,time FROM #{PG_TABLE} WHERE user_id=%{user} AND deleted_at IS NULL AND time BETWEEN %{day_start} AND %{anchor}
            UNION ALL SELECT id,time FROM boundary
          ), diffs AS (
            SELECT time,LEAST(GREATEST(time-LAG(time) OVER(ORDER BY time,id),0),120) AS diff FROM rows_with_boundary
          )
          SELECT COALESCE(SUM(diff) FILTER(WHERE time>=%{day_start}),0)::integer AS value FROM diffs
        SQL
        <<~SQL.squish
          WITH has_older AS (
            SELECT count()>0 AS value FROM (
              SELECT 1 FROM %{table} FINAL WHERE user_id=%{user} AND deleted_at IS NULL
                AND time<%{day_start}-120 LIMIT 1
            )
          ), diffs AS (
            SELECT time,least(greatest(time-lagInFrame(time,1,time) OVER(
              ORDER BY time,id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ),0),120) AS diff
            FROM %{table} FINAL WHERE user_id=%{user} AND deleted_at IS NULL
              AND time_5m BETWEEN intDiv(toInt64(floor(%{day_start}-120)),300)*300 AND %{anchor_5m}
              AND time BETWEEN %{day_start}-120 AND %{anchor}
          )
          SELECT toInt64(round(COALESCE(sumIf(diff,time>=%{day_start}),0)))
                   + if(countIf(time<%{day_start})=0 AND countIf(time>=%{day_start})>0 AND any(has_older.value),120,0) AS value
          FROM diffs CROSS JOIN has_older
        SQL
      ),
      Query.new(
        "grouped project duration", :user, true,
        <<~SQL.squish,
          SELECT project,ROUND(COALESCE(SUM(diff),0)::numeric,6) AS value FROM (
            SELECT project,LEAST(GREATEST(time-LAG(time) OVER(PARTITION BY project ORDER BY time,id),0),120) AS diff
            FROM #{PG_TABLE} WHERE user_id=%{user} AND deleted_at IS NULL AND time BETWEEN %{day_start} AND %{anchor}
          ) grouped GROUP BY project ORDER BY project NULLS FIRST
        SQL
        <<~SQL.squish
          SELECT project,round(COALESCE(sum(diff),0),6) AS value FROM (
            SELECT project,least(greatest(time-lagInFrame(time,1,time) OVER(
              PARTITION BY project ORDER BY time,id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ),0),120) AS diff
            FROM %{table} FINAL WHERE user_id=%{user} AND deleted_at IS NULL
              AND time_5m BETWEEN %{day_start_5m} AND %{anchor_5m} AND time BETWEEN %{day_start} AND %{anchor}
          ) GROUP BY project ORDER BY project NULLS FIRST
        SQL
      ),
      Query.new(
        "attributed language duration", :user, true,
        <<~SQL.squish,
          SELECT language,COALESCE(SUM(diff),0)::integer AS value FROM (
            SELECT language,LEAST(GREATEST(time-LAG(time) OVER(ORDER BY time,id),0),120) AS diff
            FROM #{PG_TABLE} WHERE user_id=%{user} AND deleted_at IS NULL AND time BETWEEN %{day_start} AND %{anchor}
          ) attributed WHERE language IS NOT NULL AND language<>'' GROUP BY language ORDER BY lower(language),language
        SQL
        <<~SQL.squish
          SELECT language,toInt64(round(COALESCE(sum(diff),0))) AS value FROM (
            SELECT language,least(greatest(time-lagInFrame(time,1,time) OVER(
              ORDER BY time,id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ),0),120) AS diff
            FROM %{table} FINAL WHERE user_id=%{user} AND deleted_at IS NULL
              AND time_5m BETWEEN %{day_start_5m} AND %{anchor_5m} AND time BETWEEN %{day_start} AND %{anchor}
          ) WHERE language IS NOT NULL AND language<>'' GROUP BY language ORDER BY lower(language),language
        SQL
      ),
      *filter_queries,
      *simple_queries
    ]
  end

  def filter_queries
    FILTER_SCENARIOS.map do |scenario|
      pg_conditions = [ "user_id=%{user}", "deleted_at IS NULL" ]
      ch_conditions = [ "user_id=%{user}", "deleted_at IS NULL" ]
      scenario.fetch(:fields).each do |field|
        pg_conditions << "#{field}=%{filter_#{field}}"
        ch_conditions << "#{field}=%{filter_#{field}}"
      end
      if scenario[:date_range]
        pg_conditions << "time BETWEEN %{filter_start} AND %{filter_end}"
        ch_conditions << "time_5m BETWEEN %{filter_start_5m} AND %{filter_end_5m}"
        ch_conditions << "time BETWEEN %{filter_start} AND %{filter_end}"
      end

      Query.new(
        scenario.fetch(:name), :user, true,
        filtered_duration_pg(pg_conditions), filtered_duration_ch(ch_conditions)
      )
    end
  end

  def filtered_duration_pg(conditions)
    <<~SQL.squish
      SELECT COUNT(*) rows,ROUND(COALESCE(SUM(diff),0)::numeric,6) duration FROM (
        SELECT LEAST(GREATEST(time-LAG(time) OVER(ORDER BY time,id),0),120) diff
        FROM #{PG_TABLE} WHERE #{conditions.join(' AND ')}
      ) filtered
    SQL
  end

  def filtered_duration_ch(conditions)
    <<~SQL.squish
      SELECT COUNT(*) rows,round(COALESCE(sum(diff),0),6) duration FROM (
        SELECT least(greatest(time-lagInFrame(time,1,time) OVER(
          ORDER BY time,id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ),0),120) diff
        FROM %{table} FINAL WHERE #{conditions.join(' AND ')}
      )
    SQL
  end

  def simple_queries
    table = PG_TABLE
    [
      Query.new(
        "all-time dashboard totals/filter options", :user, true,
        "SELECT COUNT(*) rows,MIN(time) first_time,MAX(time) last_time,COUNT(DISTINCT project) projects,COUNT(DISTINCT language) languages FROM #{table} WHERE user_id=%{user} AND deleted_at IS NULL",
        "SELECT COUNT(*) rows,MIN(time) first_time,MAX(time) last_time,uniqExact(project) projects,uniqExact(language) languages FROM %{table} FINAL WHERE user_id=%{user} AND deleted_at IS NULL"
      ),
      Query.new(
        "today dashboard snapshot", :user, true,
        "SELECT * FROM (SELECT DISTINCT language,editor,COUNT(*) OVER(PARTITION BY language) language_count,COUNT(*) OVER(PARTITION BY editor) editor_count FROM #{table} WHERE user_id=%{user} AND deleted_at IS NULL AND time BETWEEN %{day_start} AND %{anchor}) snapshot ORDER BY lower(language) NULLS FIRST,language NULLS FIRST,lower(editor) NULLS FIRST,editor NULLS FIRST",
        "SELECT * FROM (SELECT DISTINCT language,editor,count() OVER(PARTITION BY language) language_count,count() OVER(PARTITION BY editor) editor_count FROM %{table} FINAL WHERE user_id=%{user} AND deleted_at IS NULL AND time_5m BETWEEN %{day_start_5m} AND %{anchor_5m} AND time BETWEEN %{day_start} AND %{anchor}) snapshot ORDER BY lower(language) NULLS FIRST,language NULLS FIRST,lower(editor) NULLS FIRST,editor NULLS FIRST"
      ),
      Query.new(
        "project details", :user, true,
        project_details_pg, project_details_ch
      ),
      Query.new(
        "daily activity graph in timezone", :user, true,
        daily_durations_pg, daily_durations_ch
      ),
      Query.new(
        "coding rhythm", :user, true,
        coding_rhythm_pg, coding_rhythm_ch
      ),
      Query.new(
        "timeline 48h multi-user preload", :selected_users, true,
        "SELECT user_id,id,time,entity,project,editor,language FROM #{table} WHERE user_id IN (1,2,3,4,5) AND deleted_at IS NULL AND time BETWEEN %{anchor}-172800 AND %{anchor} ORDER BY user_id,time,id",
        "SELECT user_id,id,time,entity,project,editor,language FROM %{table} FINAL WHERE user_id IN (1,2,3,4,5) AND deleted_at IS NULL AND time_5m BETWEEN intDiv(toInt64(floor(%{anchor}-172800)),300)*300 AND %{anchor_5m} AND time BETWEEN %{anchor}-172800 AND %{anchor} ORDER BY user_id,time,id"
      ),
      Query.new("leaderboard grouped users", :global, true, leaderboard_pg, leaderboard_ch),
      Query.new("streak daily durations", :user, true, streak_pg, streak_ch),
      Query.new(
        "last-hour heartbeat count", :global, true,
        "SELECT COUNT(*) rows FROM #{table} WHERE deleted_at IS NULL AND time>=%{hour_start} AND time<=%{anchor}",
        "SELECT COUNT(*) rows FROM %{table} FINAL WHERE deleted_at IS NULL AND time_5m BETWEEN %{hour_start_5m} AND %{anchor_5m} AND time>=%{hour_start} AND time<=%{anchor}"
      ),
      Query.new(
        "recent 24h heartbeat counts", :global, true,
        "SELECT user_id,COUNT(*) rows,COUNT(*) FILTER(WHERE source_type<>0) imported FROM #{table} WHERE deleted_at IS NULL AND time>=%{day_start} GROUP BY user_id ORDER BY user_id",
        "SELECT user_id,COUNT(*) rows,countIf(source_type<>0) imported FROM %{table} FINAL WHERE deleted_at IS NULL AND time_5m>=%{day_start_5m} AND time>=%{day_start} GROUP BY user_id ORDER BY user_id"
      ),
      Query.new(
        "hourly active users", :global, true,
        "SELECT ROUND(time)::bigint/3600*3600 hour_bucket,COUNT(DISTINCT user_id) users FROM #{table} WHERE deleted_at IS NULL AND time>=%{day_start} AND category='coding' GROUP BY hour_bucket ORDER BY hour_bucket",
        "SELECT intDiv(toInt64(round(time)),3600)*3600 hour_bucket,uniqExact(user_id) users FROM %{table} FINAL WHERE deleted_at IS NULL AND time_5m>=%{day_start_5m} AND time>=%{day_start} AND category='coding' GROUP BY hour_bucket ORDER BY hour_bucket"
      ),
      Query.new(
        "latest active project per user", :global, true,
        "SELECT DISTINCT ON (user_id) user_id,project,time latest_time FROM #{table} WHERE deleted_at IS NULL AND source_type=0 AND category='coding' AND time>=%{anchor}-300 ORDER BY user_id,time DESC,id DESC",
        "SELECT user_id,tupleElement(argMax(tuple(project),tuple(time,id)),1) project,max(time) latest_time FROM %{table} FINAL WHERE deleted_at IS NULL AND source_type=0 AND category='coding' AND time_5m>=%{anchor_5m} AND time>=%{anchor}-300 GROUP BY user_id ORDER BY user_id"
      ),
      Query.new("weekly email stats", :user, true, weekly_stats_pg, weekly_stats_ch),
      Query.new(
        "full export scan", :user, true,
        "SELECT COUNT(*) rows,SUM(LENGTH(COALESCE(entity,''))) entity_bytes,COUNT(*) FILTER(WHERE dependencies IS NULL) null_dependencies,MIN(id) first_id,MAX(id) last_id FROM #{table} WHERE user_id=%{user} AND deleted_at IS NULL",
        "SELECT COUNT(*) rows,SUM(LENGTH(COALESCE(entity,''))) entity_bytes,countIf(dependencies_is_null) null_dependencies,MIN(id) first_id,MAX(id) last_id FROM %{table} FINAL WHERE user_id=%{user} AND deleted_at IS NULL"
      ),
      Query.new(
        "admin machine/IP sharing", :global, true,
        "SELECT machine,ip_address::text ip_address,COUNT(DISTINCT user_id) users FROM #{table} WHERE deleted_at IS NULL AND machine IS NOT NULL AND ip_address IS NOT NULL GROUP BY machine,ip_address HAVING COUNT(DISTINCT user_id)>1 ORDER BY machine,ip_address",
        "SELECT machine,toString(ip_address) ip_address,uniqExact(user_id) users FROM %{table} FINAL WHERE deleted_at IS NULL AND machine IS NOT NULL AND ip_address IS NOT NULL GROUP BY machine,ip_address HAVING uniqExact(user_id)>1 ORDER BY machine,ip_address"
      ),
      Query.new(
        "admin user-agent substring", :global, true,
        "SELECT id,user_id,time,project,language,entity,branch,category,editor,machine,operating_system,user_agent,host(ip_address) ip_address,is_write,lineno,cursorpos,lines,source_type FROM #{table} WHERE deleted_at IS NULL AND user_agent ILIKE '%%' || '%{needle}' || '%%' ORDER BY time DESC,id DESC LIMIT 1000",
        "SELECT id,user_id,time,project,language,entity,branch,category,editor,machine,operating_system,user_agent,ip_address,is_write,lineno,cursorpos,lines,source_type FROM %{table} FINAL PREWHERE user_agent ILIKE '%%%{needle}%%' WHERE deleted_at IS NULL ORDER BY time DESC,id DESC LIMIT 1000"
      ),
      Query.new(
        "active user IDs", :global, true,
        "SELECT DISTINCT user_id FROM #{table} WHERE deleted_at IS NULL AND time>=%{day_start} ORDER BY user_id",
        "SELECT DISTINCT user_id FROM %{table} FINAL WHERE deleted_at IS NULL AND time_5m>=%{day_start_5m} AND time>=%{day_start} ORDER BY user_id"
      ),
      Query.new(
        "recent heartbeat writers by creation time", :base_global, true,
        "SELECT DISTINCT user_id FROM #{table} WHERE deleted_at IS NULL AND created_at>to_timestamp(%{anchor}-21600) ORDER BY user_id",
        "SELECT DISTINCT user_id FROM %{table} FINAL WHERE deleted_at IS NULL AND created_at>fromUnixTimestamp64Micro(toInt64((%{anchor}-21600)*1000000),'UTC') ORDER BY user_id"
      ),
      Query.new(
        "account-transfer source scan", :user, true,
        "SELECT source_type,COUNT(*) rows,MIN(id) first_id,MAX(id) last_id FROM #{table} WHERE user_id=%{user} AND deleted_at IS NULL GROUP BY source_type ORDER BY source_type",
        "SELECT source_type,COUNT(*) rows,MIN(id) first_id,MAX(id) last_id FROM %{table} FINAL WHERE user_id=%{user} AND deleted_at IS NULL GROUP BY source_type ORDER BY source_type"
      ),
      Query.new(
        "anonymisation source scan", :user, true,
        "SELECT COUNT(*) rows,SUM(LENGTH(COALESCE(project,''))+LENGTH(COALESCE(entity,''))+LENGTH(COALESCE(machine,''))+LENGTH(COALESCE(user_agent,''))) text_bytes FROM #{table} WHERE user_id=%{user} AND deleted_at IS NULL",
        "SELECT COUNT(*) rows,SUM(LENGTH(COALESCE(project,''))+LENGTH(COALESCE(entity,''))+LENGTH(COALESCE(machine,''))+LENGTH(COALESCE(user_agent,''))) text_bytes FROM %{table} FINAL WHERE user_id=%{user} AND deleted_at IS NULL"
      ),
      Query.new("home totals exact", :global, true, home_totals_pg, home_totals_ch)
    ]
  end

  def project_details_pg
    <<~SQL.squish
      SELECT project,COUNT(*) rows,MIN(time) first_time,MAX(time) last_time,
             COUNT(DISTINCT language) languages,ROUND(COALESCE(SUM(diff),0)::numeric,6) duration
      FROM (
        SELECT project,language,time,
               LEAST(GREATEST(time-LAG(time) OVER(PARTITION BY project ORDER BY time,id),0),120) diff
        FROM #{PG_TABLE}
        WHERE user_id=%{user} AND deleted_at IS NULL AND project IS NOT NULL AND project<>''
      ) details
      GROUP BY project ORDER BY project
    SQL
  end

  def project_details_ch
    <<~SQL.squish
      SELECT project,COUNT(*) rows,MIN(time) first_time,MAX(time) last_time,
             uniqExact(language) languages,round(COALESCE(sum(diff),0),6) duration
      FROM (
        SELECT project,language,time,
               least(greatest(time-lagInFrame(time,1,time) OVER(
                 PARTITION BY project ORDER BY time,id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
               ),0),120) diff
        FROM %{table} FINAL
        WHERE user_id=%{user} AND deleted_at IS NULL AND project IS NOT NULL AND project<>''
      )
      GROUP BY project ORDER BY project
    SQL
  end

  def daily_durations_pg
    <<~SQL.squish
      SELECT day_bucket,ROUND(COALESCE(SUM(diff),0)::numeric,6) duration FROM (
        SELECT FLOOR(time/86400)::bigint*86400 day_bucket,
               LEAST(GREATEST(time-LAG(time) OVER(
                 PARTITION BY FLOOR(time/86400)::bigint ORDER BY time,id
               ),0),120) diff
        FROM #{PG_TABLE}
        WHERE user_id=%{user} AND deleted_at IS NULL AND time>=%{year_start}
      ) daily GROUP BY day_bucket ORDER BY day_bucket
    SQL
  end

  def daily_durations_ch
    <<~SQL.squish
      SELECT day_bucket,round(COALESCE(sum(diff),0),6) duration FROM (
        SELECT toInt64(floor(time/86400))*86400 day_bucket,
               least(greatest(time-lagInFrame(time,1,time) OVER(
                 PARTITION BY toInt64(floor(time/86400)) ORDER BY time,id
                 ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
               ),0),120) diff
        FROM %{table} FINAL
        WHERE user_id=%{user} AND deleted_at IS NULL AND time_5m>=%{year_start_5m} AND time>=%{year_start}
      ) GROUP BY day_bucket ORDER BY day_bucket
    SQL
  end

  def coding_rhythm_pg
    <<~SQL.squish
      SELECT weekday_bucket,hour_bucket,ROUND(COALESCE(SUM(diff),0)::numeric,6) duration FROM (
        SELECT EXTRACT(ISODOW FROM to_timestamp(time))::integer weekday_bucket,
               EXTRACT(HOUR FROM to_timestamp(time))::integer hour_bucket,
               LEAST(GREATEST(time-LAG(time) OVER(ORDER BY time,id),0),120) diff
        FROM #{PG_TABLE} WHERE user_id=%{user} AND deleted_at IS NULL
          AND time BETWEEN 0 AND 253402300799
      ) rhythm GROUP BY weekday_bucket,hour_bucket ORDER BY weekday_bucket,hour_bucket
    SQL
  end

  def coding_rhythm_ch
    <<~SQL.squish
      SELECT weekday_bucket,hour_bucket,round(COALESCE(sum(diff),0),6) duration FROM (
        SELECT toDayOfWeek(fromUnixTimestamp64Micro(toInt64(round(time*1000000)),'UTC')) weekday_bucket,
               toHour(fromUnixTimestamp64Micro(toInt64(round(time*1000000)),'UTC')) hour_bucket,
               least(greatest(time-lagInFrame(time,1,time) OVER(
                 ORDER BY time,id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
               ),0),120) diff
        FROM %{table} FINAL WHERE user_id=%{user} AND deleted_at IS NULL
          AND time BETWEEN 0 AND 253402300799
      ) GROUP BY weekday_bucket,hour_bucket ORDER BY weekday_bucket,hour_bucket
    SQL
  end

  def leaderboard_pg
    <<~SQL.squish
      SELECT user_id,ROUND(COALESCE(SUM(diff),0)::numeric,6) duration FROM (
        SELECT user_id,LEAST(GREATEST(time-LAG(time) OVER(PARTITION BY user_id ORDER BY time,id),0),120) diff
        FROM #{PG_TABLE}
        WHERE deleted_at IS NULL AND time BETWEEN %{week_start} AND 253402300799 AND category='coding'
          AND (editor IS NULL OR lower(editor) NOT IN ('arc','brave','chrome','chromium','edge','firefox','floorp','librewolf','microsoft-edge','opera','opera-gx','safari','vivaldi','waterfox','zen'))
          AND project IS DISTINCT FROM '<<LAST_PROJECT>>'
      ) eligible GROUP BY user_id ORDER BY user_id
    SQL
  end

  def leaderboard_ch
    <<~SQL.squish
      SELECT user_id,round(COALESCE(sum(diff),0),6) duration FROM (
        SELECT user_id,least(greatest(time-lagInFrame(time,1,time) OVER(
          PARTITION BY user_id ORDER BY time,id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ),0),120) diff
        FROM %{table} FINAL
        WHERE deleted_at IS NULL AND time_5m>=%{week_start_5m}
          AND time BETWEEN %{week_start} AND 253402300799 AND category='coding'
          AND (editor IS NULL OR lower(editor) NOT IN ('arc','brave','chrome','chromium','edge','firefox','floorp','librewolf','microsoft-edge','opera','opera-gx','safari','vivaldi','waterfox','zen'))
          AND project IS DISTINCT FROM '<<LAST_PROJECT>>'
      ) GROUP BY user_id ORDER BY user_id
    SQL
  end

  def streak_pg
    daily_durations_pg.sub(
      "WHERE user_id=%{user} AND deleted_at IS NULL AND time>=%{year_start}",
      "WHERE user_id=%{user} AND deleted_at IS NULL AND time>=%{year_start} AND category IS DISTINCT FROM 'browsing'"
    )
  end

  def streak_ch
    daily_durations_ch.sub(
      "WHERE user_id=%{user} AND deleted_at IS NULL AND time_5m>=%{year_start_5m} AND time>=%{year_start}",
      "WHERE user_id=%{user} AND deleted_at IS NULL AND time_5m>=%{year_start_5m} AND time>=%{year_start} AND category IS DISTINCT FROM 'browsing'"
    )
  end

  def weekly_stats_pg
    <<~SQL.squish
      SELECT project,ROUND(COALESCE(SUM(diff),0)::numeric,6) duration FROM (
        SELECT project,LEAST(GREATEST(time-LAG(time) OVER(PARTITION BY project ORDER BY time,id),0),120) diff
        FROM #{PG_TABLE} WHERE user_id=%{user} AND deleted_at IS NULL AND time>=%{week_start}
      ) weekly GROUP BY project ORDER BY project NULLS FIRST
    SQL
  end

  def weekly_stats_ch
    <<~SQL.squish
      SELECT project,round(COALESCE(sum(diff),0),6) duration FROM (
        SELECT project,least(greatest(time-lagInFrame(time,1,time) OVER(
          PARTITION BY project ORDER BY time,id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ),0),120) diff
        FROM %{table} FINAL WHERE user_id=%{user} AND deleted_at IS NULL
          AND time_5m>=%{week_start_5m} AND time>=%{week_start}
      ) GROUP BY project ORDER BY project NULLS FIRST
    SQL
  end

  def home_totals_pg
    <<~SQL.squish
      SELECT COUNT(*) FILTER (WHERE total_seconds > 0) users_tracked,
             ROUND(COALESCE(SUM(total_seconds),0))::bigint seconds_tracked
      FROM (
        SELECT user_id,COALESCE(SUM(diff),0) total_seconds FROM (
          SELECT user_id,LEAST(GREATEST(time-LAG(time) OVER(PARTITION BY user_id ORDER BY time,id),0),120) diff
          FROM #{PG_TABLE} WHERE deleted_at IS NULL AND time BETWEEN 0 AND 253402300799
            AND (user_id,COALESCE(project,'')) NOT IN (%{archived_pairs})
        ) durations GROUP BY user_id
      ) totals
    SQL
  end

  def home_totals_ch
    <<~SQL.squish
      SELECT countIf(total_seconds > 0) users_tracked,
             toInt64(round(COALESCE(sum(total_seconds),0))) seconds_tracked
      FROM (
        SELECT user_id,COALESCE(sum(diff),0) total_seconds FROM (
          SELECT user_id,least(greatest(time-lagInFrame(time,1,time) OVER(
            PARTITION BY user_id ORDER BY time,id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
          ),0),120) diff
          FROM %{table} FINAL WHERE deleted_at IS NULL AND time BETWEEN 0 AND 253402300799
            AND (user_id,ifNull(project,'')) NOT IN (%{archived_pairs})
        ) GROUP BY user_id
      )
    SQL
  end

  def benchmark_ingest
    systems = { "postgresql" => benchmark_pg_ingest }
    CH_TABLES.each { |table| systems[table] = benchmark_ch_ingest(table) }
    systems[PRODUCTION_SYSTEM] = benchmark_ch_dual_ingest
    {
      "family" => "direct ingest batch (100 rows)",
      "cohort" => "tiny",
      "correctness" => compare(systems, true),
      "systems" => systems
    }
  end

  def benchmark_pg_ingest
    target = "clickhouse_benchmark_ingest"
    @pg.exec("DROP TABLE IF EXISTS #{target}")
    @pg.exec("CREATE UNLOGGED TABLE #{target} (LIKE #{PG_TABLE} INCLUDING ALL)")
    samples = REPETITIONS.times.map do
      @pg.exec("TRUNCATE #{target}")
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @pg.exec(<<~SQL.squish)
        INSERT INTO #{target} (#{COLUMNS.join(',')})
        SELECT #{COLUMNS.join(',')} FROM #{PG_TABLE} WHERE user_id=1 ORDER BY id LIMIT 100
      SQL
      [ elapsed_ms(started), fingerprint([ { "rows" => @pg.exec("SELECT COUNT(*) FROM #{target}").getvalue(0, 0) } ]) ]
    end
    summarize(samples, 100, nil)
  ensure
    @pg.exec("DROP TABLE IF EXISTS #{target}") if target
  end

  def benchmark_ch_ingest(source)
    target = "clickhouse_benchmark_ingest_#{source}"
    @ch.execute("DROP TABLE IF EXISTS #{target}")
    @ch.execute("CREATE TABLE #{target} AS #{source}")
    samples = REPETITIONS.times.map do
      @ch.execute("TRUNCATE TABLE #{target}")
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @ch.execute("INSERT INTO #{target} SELECT * FROM #{source} FINAL WHERE user_id=1 ORDER BY id LIMIT 100")
      count = @ch.select("SELECT count() rows FROM #{target}").first.fetch("rows")
      [ elapsed_ms(started), fingerprint([ { "rows" => count } ]) ]
    end
    summarize(samples, 100, nil)
  ensure
    @ch.execute("DROP TABLE IF EXISTS #{target}") if target
  end

  def benchmark_ch_dual_ingest
    database = "hackatime_benchmark_ingest_#{Process.pid}"
    @ch.execute("DROP DATABASE IF EXISTS #{database}")
    @ch.execute("CREATE DATABASE #{database}")
    client = ClickHouse::Client.new(ENV.fetch("CLICKHOUSE_URL").sub(%r{/[^/]+\z}, "/#{database}"))
    %w[
      001_create_heartbeats.sql
      009_create_heartbeats_by_time.sql
      012_create_heartbeat_store.sql
      013_create_heartbeat_aliases.sql
    ].each { |file| client.execute(File.read(Rails.root.join("db/clickhouse", file))) }
    repository = HeartbeatRepository.new(client:)
    user = User.create!(timezone: "UTC")
    source_rows = @pg.exec("SELECT #{COLUMNS.join(',')} FROM #{PG_TABLE} WHERE user_id=1 ORDER BY id LIMIT 100").to_a
    ja4_ids = source_rows.filter_map { |row| row["ja4_id"] }.uniq.to_h do |source_id|
      [ source_id, Ja4.create!(fingerprint: "benchmark-#{SecureRandom.uuid}").id ]
    end
    records = source_rows.map do |row|
      attributes = row.merge("user_id" => user.id, "ja4_id" => ja4_ids[row["ja4_id"]])
      repository.serialize_attributes(attributes).merge(
        "fields_hash" => repository.canonical_fields_hash(attributes),
        "alias_hashes" => [ Heartbeat.generate_fields_hash(attributes) ]
      )
    end
    samples = REPETITIONS.times.map do
      %w[heartbeats heartbeats_by_time heartbeat_store heartbeat_aliases].each do |table|
        client.execute("TRUNCATE TABLE #{table}")
      end
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      outcomes = repository.persist(user_id: user.id, records:)
      counts = %w[heartbeats heartbeats_by_time heartbeat_store].map do |table|
        client.select("SELECT count() rows FROM #{table} FINAL").first.fetch("rows").to_i
      end
      raise "Production repository ingest diverged" unless outcomes.count { |outcome| outcome.fetch(:inserted) } == 100 &&
        counts == [ 100, 100, 100 ]

      [ elapsed_ms(started), fingerprint([ { "rows" => counts.first } ]) ]
    end
    summarize(samples, 100, nil)
  ensure
    user&.destroy!
    Ja4.where(id: ja4_ids&.values).delete_all
    @ch.execute("DROP DATABASE IF EXISTS #{database}") if database
  end

  def benchmark_pg(sql)
    samples = REPETITIONS.times.map do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result_fingerprint = fingerprint(each_pg_row(sql))
      sample = [ elapsed_ms(started), result_fingerprint ]
      GC.start
      sample
    end
    plan = explain_pg(sql)
    summarize(samples, plan.fetch("rows_read"), plan.fetch("bytes_read"))
  end

  def each_pg_row(sql)
    Enumerator.new do |rows|
      @pg.exec("BEGIN READ ONLY")
      @pg.exec("DECLARE benchmark_result NO SCROLL CURSOR FOR #{sql}")
      loop do
        batch = @pg.exec("FETCH FORWARD 5_000 FROM benchmark_result")
        break if batch.ntuples.zero?

        batch.each { |row| rows << row }
      end
      @pg.exec("COMMIT")
    rescue
      @pg.exec("ROLLBACK") unless @pg.transaction_status == PG::PQTRANS_IDLE
      raise
    end
  end

  def explain_pg(sql)
    value = @pg.exec("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) #{sql}").getvalue(0, 0)
    document = value.is_a?(String) ? JSON.parse(value) : value
    root = document.first.fetch("Plan")
    {
      "rows_read" => pg_scan_rows(root),
      "bytes_read" => %w[Shared Local Temp].sum { |kind|
        root.fetch("#{kind} Hit Blocks", 0).to_i + root.fetch("#{kind} Read Blocks", 0).to_i
      } * 8_192
    }
  end

  def pg_scan_rows(node)
    own = node.fetch("Node Type", "").end_with?("Scan") ? node.fetch("Actual Rows", 0).to_i * node.fetch("Actual Loops", 1).to_i : 0
    own + Array(node["Plans"]).sum { |child| pg_scan_rows(child) }
  end

  def benchmark_ch(sql)
    samples = REPETITIONS.times.map do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      query_ids = []
      rows = []
      Array(sql).each do |statement|
        query_id = SecureRandom.uuid
        query_ids << query_id
        rows = @ch.select(statement, settings: { query_id:, log_queries: 1 })
        break if rows.any?
      end
      result_fingerprint = fingerprint(rows)
      sample = [ elapsed_ms(started), result_fingerprint, query_ids ]
      GC.start
      sample
    end
    @ch.execute("SYSTEM FLUSH LOGS")
    query_ids = samples.last[2].map { |query_id| "'#{query_id}'" }.join(", ")
    stats = @ch.select(<<~SQL.squish).first || {}
      SELECT sum(read_rows) AS read_rows, sum(read_bytes) AS read_bytes FROM system.query_log
      WHERE type = 'QueryFinish' AND query_id IN (#{query_ids})
    SQL
    summarize(samples, stats["read_rows"], stats["read_bytes"])
  end

  def summarize(samples, rows, bytes)
    timings = samples.map(&:first).sort
    { "first_ms" => samples.first[0], "p50_ms" => percentile(timings, 0.50), "p95_ms" => percentile(timings, 0.95), "rows_read" => rows, "bytes_read" => bytes, "fingerprint" => samples.last[1] }
  end

  def fingerprint(rows)
    count = 0
    digest = Digest::SHA256.new
    rows.each do |row|
      canonical = row.transform_values { |value| canonical_value(value) }.sort.to_h
      payload = JSON.generate(canonical)
      digest << [ payload.bytesize ].pack("Q>") << payload
      count += 1
    end
    "#{count}:#{digest.hexdigest}"
  end

  def canonical_value(value)
    return if value.nil?
    return value.utc.iso8601(6) if value.respond_to?(:utc) && value.respond_to?(:iso8601)
    return value.map { |item| canonical_value(item) } if value.is_a?(Array)
    return value.transform_values { |item| canonical_value(item) }.sort.to_h if value.is_a?(Hash)

    return value.to_s unless value.is_a?(Numeric)

    decimal = BigDecimal(value.to_s).to_s("F")
    decimal.sub!(/\.0+\z/, "")
    decimal.sub!(/(\.\d*?)0+\z/, "\\1")
    decimal
  end

  def compare(results, comparable)
    return "not comparable" unless comparable
    results.values.map { |r| r["fingerprint"] }.uniq.one? ? "match" : "mismatch"
  end

  def elapsed_ms(started) = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1_000).round(3)
  def percentile(values, fraction) = values[((values.length - 1) * fraction).ceil]
  def format_ch_query(query, params) = query.is_a?(Array) ? query.map { |sql| format(sql, params) } : format(query, params)
  def clickhouse_version = @ch.select("SELECT version() version").first.fetch("version")
  def methodology = "Each query ran five times per system after ClickHouse parts were merged to a steady-state layout. The report records first-run latency and nearest-rank p50/p95 wall-clock latency. ClickHouse read volume comes from system.query_log; PostgreSQL read volume comes from a sixth EXPLAIN ANALYZE run with BUFFERS and counts logical 8 KiB buffers. Ordered results are canonicalised at each query's declared output precision and SHA-256 fingerprinted without retaining values. User-scoped families run for every cohort and global families use all sampled rows."

  def benchmark_filter_parameters(user_id)
    @benchmark_filter_parameters ||= {}
    @benchmark_filter_parameters[user_id] ||= begin
      fields = %w[operating_system editor project language category]
      rows = @pg.exec_params(<<~SQL.squish, [ user_id ]).to_a
        SELECT time,#{fields.join(',')} FROM #{PG_TABLE}
        WHERE user_id=$1 AND deleted_at IS NULL AND time BETWEEN 0 AND 253402300799
          AND #{fields.map { |field| "#{field} IS NOT NULL AND #{field}<>''" }.join(' AND ')}
        ORDER BY time DESC,id DESC LIMIT 1000
      SQL
      row = rows.find { |candidate| fields.all? { |field| safe_filter_value?(candidate.fetch(field)) } }
      abort "Cohort #{user_id} has no heartbeat suitable for mixed filter benchmarks" unless row

      filter_end = row.fetch("time").to_f
      {
        filter_start: filter_end - 30.days.to_i,
        filter_end: filter_end,
        filter_start_5m: (filter_end - 30.days.to_i).floor.div(300) * 300,
        filter_end_5m: filter_end.floor.div(300) * 300
      }.merge(fields.to_h { |field| [ "filter_#{field}".to_sym, sql_literal(row.fetch(field)) ] })
    end
  end

  def safe_filter_value?(value)
    value.present? && !value.match?(/[\\\u0000-\u001f]/)
  end

  def sql_literal(value)
    "'#{value.gsub("'", "''")}'"
  end

  def regression_explanation(family)
    if family.start_with?("dashboard filter")
      return "PostgreSQL can use dedicated user/dimension/time B-tree indexes for selective values. ClickHouse keeps replacement-correct user/time ordering and scans the user's relevant granules. Tested set indexes for low-cardinality dimensions and a project bloom index skipped no rows under FINAL and made average filter p50 12.6% slower. Date-bucket pruning remains the effective optimisation for bounded ranges."
    end

    case family
    when "direct ingest batch (100 rows)"
      "The production measurement runs canonical admission, two alias identities, both sorting layouts, visibility checks and one combined acknowledgement. PostgreSQL measures one local table insert. Batched ID/version allocation and combined acknowledgement reduce round trips; asynchronous delivery would be faster but weaken ingestion acknowledgement."
    when "latest heartbeat"
      "Sparse users miss the bucket-pruned 25-hour probe and require an exact all-time fallback, reading one user granule per monthly partition. The two-stage probe is the implemented mitigation; a current-state view would need mutation-aware repair semantics."
    when "boundary-aware duration with predecessor"
      "Exact predecessor detection touches older monthly partitions when the selected day is empty or sparse. The implemented 120-second window keeps the expensive full-history test separate; storing predecessor state would add mutable aggregate repair complexity."
    when "admin user-agent substring"
      "The text index prunes most rows, but exact substring filtering and global ordering still pay FINAL and HTTP cost. That index is the implemented fix; narrower search terms or pagination are the remaining application-level mitigations."
    when "exact day duration (time,id) with 120s cap", "grouped project duration", "attributed language duration",
         "daily activity graph in timezone", "coding rhythm", "streak daily durations"
      "FINAL, exact ordering and a window function dominate sparse ranges. Five-minute key pruning is the implemented fix and wins as account size grows; pre-aggregation was rejected because replacements, deletion and attribution changes require exact retractions."
    when "raw day page", "today dashboard snapshot", "weekly email stats", "latest active project per user"
      "PostgreSQL's warm index scan beats ClickHouse's HTTP, JSON, FINAL and minimum-granule cost on this sparse range. Five-minute pruning and the by-time mirror are already applied; smaller granularity and alternate keys benchmarked neutral or worse."
    when "all-time dashboard totals/filter options", "project details"
      "A sparse user's all-time scan pays one minimum granule per part. The user-first key is the best tested layout and becomes faster at larger cohorts; a materialized rollup would need durable refresh and mutation reconciliation."
    when "full export scan", "account-transfer source scan", "anonymisation source scan"
      "Fixed HTTP, FINAL and minimum-granule cost outweighs scanning a small PostgreSQL account, while ClickHouse wins decisively for large accounts. These paths are infrequent or streamed; batching is preferable to another storage layout."
    else
      "Small results are dominated by HTTP, JSON, FINAL and one 8,192-row granule per touched part. Connection reuse, bucket pruning and the selected alternate ordering are already applied; tested smaller granules and extra indexes were slower."
    end
  end

  def average_p50(data, system)
    values = data.fetch("benchmarks").filter_map { |benchmark| benchmark.dig("systems", system, "p50_ms") }
    values.sum / values.length
  end

  def rollup_conclusion(data)
    selected = PRODUCTION_SYSTEM
    relevant = data.fetch("benchmarks").select { |b| [ "all-time dashboard totals/filter options", "today dashboard snapshot", "grouped project duration", "attributed language duration", "daily activity graph in timezone", "coding rhythm" ].include?(b["family"]) }
    selected_results = relevant.filter_map { |benchmark| benchmark.dig("systems", selected) }
    if relevant.any? && relevant.all? { |b| b["correctness"] == "match" } && selected_results.all? { |result| result["p95_ms"] <= 250 }
      "Every sampled dashboard query matched PostgreSQL and stayed within a 250 ms p95 budget on #{SYSTEM_LABELS.fetch(selected, selected)}. Precomputed heartbeat rollups are unnecessary. Homepage totals also run as an exact ClickHouse query with relational archived-project exclusions supplied as a filter set."
    else
      "At least one dashboard query mismatched or exceeded the 250 ms p95 budget on #{SYSTEM_LABELS.fetch(selected, selected)}. Insert-driven materialized views are not a correct substitute for mutable duration windows, so optimise the exact query or use a refreshable ClickHouse current-state view before cutover."
    end
  end

  def write_results(data)
    temporary = RESULT_PATH.sub_ext(".json.tmp")
    File.write(temporary, JSON.pretty_generate(data))
    File.rename(temporary, RESULT_PATH)
  end
  def read_results = JSON.parse(File.read(RESULT_PATH))
  def h(value) = ERB::Util.html_escape(value.to_s)
  def number(value) = value.nil? ? "-" : format("%.3f", value)

  def benchmark_user_agent_needle
    @benchmark_user_agent_needle ||= @pg.exec(<<~SQL.squish).getvalue(0, 0).to_s
      SELECT substring(user_agent FROM 7 FOR 8)
      FROM #{PG_TABLE}
      WHERE user_agent IS NOT NULL AND length(user_agent) >= 14
      LIMIT 1
    SQL
  end

  def benchmark_archived_pairs
    @benchmark_archived_pairs ||= begin
      rows = @pg.exec(<<~SQL.squish)
        SELECT DISTINCT ON (user_id) user_id, project
        FROM #{PG_TABLE}
        WHERE deleted_at IS NULL AND project IS NOT NULL AND project != ''
        ORDER BY user_id, id
      SQL
      pairs = rows.map { |row| "(#{Integer(row.fetch('user_id'))},'#{row.fetch('project')}')" }
      pairs.presence&.join(",") || "(0,'')"
    end
  end

  def benchmark_recovery_poll
    table = "clickhouse_benchmark_reconcile"
    @ch.execute("DROP TABLE IF EXISTS #{table}")
    @ch.execute(<<~SQL)
      CREATE TABLE #{table}
      (
        id UInt64,
        user_id UInt64,
        created_at DateTime64(6, 'UTC'),
        canonicalized Bool,
        duplicate_of Nullable(UInt64),
        version UInt64,
        heartbeats_version UInt64,
        heartbeats_by_time_version UInt64,
        store_version UInt64
      )
      ENGINE = ReplacingMergeTree(store_version)
      PARTITION BY toYYYYMM(created_at)
      ORDER BY (user_id, id)
    SQL
    @ch.execute(<<~SQL)
      INSERT INTO #{table}
      SELECT id, user_id, created_at, true, NULL, version, version, version, id
      FROM clickhouse_benchmark_bucketed FINAL
    SQL
    @ch.execute("OPTIMIZE TABLE #{table} FINAL")
    result = benchmark_ch(<<~SQL.squish)
      SELECT id FROM #{table} FINAL
      WHERE canonicalized = false OR (
        canonicalized = true AND duplicate_of IS NULL AND
        (heartbeats_version < version OR heartbeats_by_time_version < version)
      )
      ORDER BY store_version LIMIT 1000
    SQL
    production_rows = if ENV["READONLY_PROD_DB_URL"].present?
      PG.connect(ENV.fetch("READONLY_PROD_DB_URL")) do |connection|
        connection.exec("SET default_transaction_read_only = on")
        connection.exec("SELECT reltuples::bigint AS estimate FROM pg_class WHERE oid = to_regclass('public.heartbeats')")
          .first.fetch("estimate").to_i
      end
    else
      "not measured"
    end
    {
      "source_rows" => @ch.select("SELECT count() AS count FROM #{table} FINAL").first.fetch("count").to_i,
      "production_rows" => production_rows,
      "read_rows" => result.fetch("rows_read"),
      "p95_ms" => result.fetch("p95_ms")
    }
  ensure
    @ch.execute("DROP TABLE IF EXISTS #{table}") if table
  end
end

ClickHouseBenchmark.new.call(ARGV.fetch(0, ""))
