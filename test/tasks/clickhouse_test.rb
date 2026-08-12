require "test_helper"
require "rake"

Rails.application.load_tasks unless Rake::Task.task_defined?("clickhouse:purge_postgres")

class ClickhouseTaskTest < ActiveSupport::TestCase
  setup do
    @previous_store = ENV["HEARTBEAT_STORE"]
    @previous_writes_stopped = ENV["HEARTBEAT_WRITES_STOPPED"]
    @previous_mutations_stopped = ENV["HEARTBEAT_MUTATIONS_STOPPED"]
    @previous_clickhouse_test = ENV["CLICKHOUSE_TEST"]
    @previous_clickhouse_url = ENV["CLICKHOUSE_URL"]
    @previous_batch_size = ENV["BATCH_SIZE"]
    @previous_table = ENV["TABLE"]
    @previous_partition = ENV["PARTITION"]
    @previous_after_user_id = ENV["AFTER_USER_ID"]
    @previous_after_id = ENV["AFTER_ID"]
    @previous_client = ClickHouse::Client.instance_variable_get(:@current)
    @previous_repository = HeartbeatRepository.instance_variable_get(:@current)
  end

  teardown do
    @admin&.execute("DROP DATABASE IF EXISTS #{@database}") if @database
    restore_env("HEARTBEAT_STORE", @previous_store)
    restore_env("HEARTBEAT_WRITES_STOPPED", @previous_writes_stopped)
    restore_env("HEARTBEAT_MUTATIONS_STOPPED", @previous_mutations_stopped)
    restore_env("CLICKHOUSE_TEST", @previous_clickhouse_test)
    restore_env("CLICKHOUSE_URL", @previous_clickhouse_url)
    restore_env("BATCH_SIZE", @previous_batch_size)
    restore_env("TABLE", @previous_table)
    restore_env("PARTITION", @previous_partition)
    restore_env("AFTER_USER_ID", @previous_after_user_id)
    restore_env("AFTER_ID", @previous_after_id)
    ClickHouse::Client.instance_variable_set(:@current, @previous_client)
    HeartbeatRepository.instance_variable_set(:@current, @previous_repository)
    %w[migrate backfill verify drain_outbox repair_query_layouts reseed_postgres_sequences replay_lifecycle_controls purge_postgres].each do |task|
      Rake::Task["clickhouse:#{task}"].reenable
    end
  end

  test "PostgreSQL purge requires the application write fence" do
    ENV["HEARTBEAT_STORE"] = "clickhouse"
    ENV["CLICKHOUSE_TEST"] = "1"
    ENV.delete("HEARTBEAT_WRITES_STOPPED")

    error = assert_raises(SystemExit) { capture_io { Rake::Task["clickhouse:purge_postgres"].invoke } }
    assert_equal 1, error.status
  end

  test "PostgreSQL backfill requires the mutation fence" do
    ENV["HEARTBEAT_STORE"] = "postgresql"
    ENV["CLICKHOUSE_TEST"] = "0"
    ENV.delete("HEARTBEAT_MUTATIONS_STOPPED")

    _output, error_output = capture_io do
      error = assert_raises(SystemExit) { Rake::Task["clickhouse:backfill"].invoke }
      assert_equal 1, error.status
    end
    assert_includes error_output, "Set HEARTBEAT_MUTATIONS_STOPPED=1"
  end

  test "PostgreSQL purge rolls back its payload, rollup and fence changes together" do
    ENV["CLICKHOUSE_TEST"] = "0"
    user = User.create!(
      timezone: "UTC",
      dashboard_rollup_generation: 4,
      dashboard_rollup_refreshed_generation: 3
    )
    heartbeat = Heartbeat.create!(
      user:,
      time: Time.current.to_f,
      entity: "rollback.rb",
      source_type: :direct_entry
    )
    user.update!(dashboard_rollup_generation: 4, dashboard_rollup_refreshed_generation: 3)
    rollup = DashboardRollup.create!(
      user:,
      dimension: DashboardRollup::TOTAL_DIMENSION,
      bucket_value: "",
      bucket_value_present: false,
      total_seconds: 60
    )
    cutover = HeartbeatCutover.create!(
      id: 1,
      source_through_id: heartbeat.id,
      backfilled_through_id: heartbeat.id,
      verified_through_id: heartbeat.id,
      verified_at: Time.current
    )
    expected_generations = user.reload.values_at(:dashboard_rollup_generation, :dashboard_rollup_refreshed_generation)
    original_update_all = User.method(:update_all)
    User.define_singleton_method(:update_all) do |*arguments, **keywords|
      original_update_all.call(*arguments, **keywords)
      raise "interrupted after PostgreSQL truncation"
    end

    error = assert_raises(RuntimeError) { cutover.purge_postgresql! }
    assert_equal "interrupted after PostgreSQL truncation", error.message

    assert Heartbeat.postgresql_unscoped.exists?(heartbeat.id)
    assert DashboardRollup.exists?(rollup.id)
    assert_nil cutover.reload.purged_at
    assert_equal expected_generations,
      user.reload.values_at(:dashboard_rollup_generation, :dashboard_rollup_refreshed_generation)
  ensure
    User.define_singleton_method(:update_all, original_update_all) if original_update_all
  end

  test "PostgreSQL purge refuses a heartbeat inserted after its verified boundary" do
    ENV["CLICKHOUSE_TEST"] = "0"
    user = User.create!(timezone: "UTC")
    cutover = HeartbeatCutover.create!(
      id: 1,
      source_through_id: 0,
      backfilled_through_id: 0,
      verified_through_id: 0,
      verified_at: Time.current
    )

    result = HeartbeatIngest.call(
      user:,
      mode: :direct,
      heartbeats: [ { entity: "late.rb", time: Time.current.to_f, type: "file" } ],
      schedule_rollup_refresh: false
    )
    assert_equal 1, result.persisted_count

    error = assert_raises(HeartbeatCutover::PurgeBlocked) { cutover.purge_postgresql! }
    assert_equal "PostgreSQL received heartbeats after the recorded source boundary", error.message
    assert_nil cutover.reload.purged_at
    assert_equal 1, Heartbeat.postgresql_unscoped.where(user_id: user.id).count
  end

  test "migration rejects unknown production history with safe remediation" do
    require_clickhouse_integration!

    setup_clickhouse_database
    @client.insert_json_each_row("schema_migrations", [ { version: "999_removed_history" } ])

    _output, error_output = capture_io do
      error = assert_raises(SystemExit) { Rake::Task["clickhouse:migrate"].tap(&:reenable).invoke }
      assert_equal 1, error.status
    end
    assert_includes error_output, "Unknown ClickHouse migrations: 999_removed_history"
    assert_includes error_output, "Do not delete production history"
  end

  test "migration upgrades a database with multiple pending schema changes" do
    require_clickhouse_integration!

    setup_clickhouse_database
    %w[heartbeats heartbeats_by_time].each do |table|
      @client.execute("ALTER TABLE #{table} ADD COLUMN time_epoch Int64 DEFAULT 0")
      @client.execute("ALTER TABLE #{table} ADD COLUMN time_hour Int64 DEFAULT 0")
    end
    @client.execute("TRUNCATE TABLE schema_migrations")
    applied = %w[
      001_create_heartbeats
      009_create_heartbeats_by_time
      010_drop_heartbeats_by_time_ingest
      012_create_heartbeat_store
      013_create_heartbeat_aliases
    ].map { |version| { version: } }
    @client.insert_json_each_row("schema_migrations", applied)

    invoke_task("migrate")

    %w[heartbeats heartbeats_by_time].each do |table|
      columns = @client.select("DESCRIBE TABLE #{table}").pluck("name")
      assert_not_includes columns, "time_epoch"
      assert_not_includes columns, "time_hour"
    end
    expected = Dir[Rails.root.join("db/clickhouse/*.sql")].map { |path| File.basename(path, ".sql") }.sort
    assert_equal expected, @client.select("SELECT DISTINCT version FROM schema_migrations").pluck("version").sort
  end

  test "backfill rejects finite times outside ClickHouse Int64 buckets" do
    require_clickhouse_integration!

    setup_clickhouse_database
    ENV["HEARTBEAT_STORE"] = "postgresql"
    ENV["CLICKHOUSE_TEST"] = "0"
    ENV["HEARTBEAT_MUTATIONS_STOPPED"] = "1"
    user = User.create!(timezone: "UTC")
    heartbeat = Heartbeat.create!(user:, time: Time.current.to_f, entity: "extreme.rb", source_type: :direct_entry)
    heartbeat.update_column(:time, (2**63).to_f)

    _output, error_output = capture_io do
      error = assert_raises(SystemExit) { Rake::Task["clickhouse:backfill"].tap(&:reenable).invoke }
      assert_equal 1, error.status
    end
    assert_includes error_output, "heartbeats exceed ClickHouse Int64 time buckets"
  end

  test "two-pass backfill verifies the fenced PostgreSQL boundary" do
    require_clickhouse_integration!

    @admin = @previous_client || ClickHouse::Client.new(@previous_clickhouse_url)
    @database = "hackatime_cutover_test_#{Process.pid}"
    @admin.execute("DROP DATABASE IF EXISTS #{@database}")
    @admin.execute("CREATE DATABASE #{@database}")
    client = ClickHouse::Client.new(@previous_clickhouse_url.sub(%r{/[^/]+\z}, "/#{@database}"))
    ClickHouse::Client.instance_variable_set(:@current, client)
    HeartbeatRepository.instance_variable_set(:@current, HeartbeatRepository.new(client:))
    ENV["CLICKHOUSE_URL"] = @previous_clickhouse_url.sub(%r{/[^/]+\z}, "/#{@database}")
    ENV["CLICKHOUSE_TEST"] = "0"
    ENV["HEARTBEAT_STORE"] = "postgresql"
    ENV["BATCH_SIZE"] = "1"
    ENV["HEARTBEAT_MUTATIONS_STOPPED"] = "1"
    ENV.delete("HEARTBEAT_WRITES_STOPPED")

    invoke_task("migrate")
    user = User.create!(timezone: "UTC")
    started_at = Time.current.to_i.to_f
    first = Heartbeat.create!(user:, time: started_at, entity: "first.rb", source_type: :direct_entry)

    invoke_task("backfill")
    cutover = HeartbeatCutover.find(1)
    assert_equal first.id, cutover.source_through_id
    assert_equal first.id, cutover.backfilled_through_id
    assert_equal 1, client.select("SELECT count() AS count FROM heartbeats FINAL").sole.fetch("count").to_i

    second = Heartbeat.create!(user:, time: started_at + 30, entity: "second.rb", source_type: :direct_entry)
    invoke_task("backfill")
    assert_equal first.id, cutover.reload.source_through_id
    assert_equal 1, client.select("SELECT count() AS count FROM heartbeats FINAL").sole.fetch("count").to_i

    ENV["HEARTBEAT_WRITES_STOPPED"] = "1"
    invoke_task("backfill")
    assert_equal second.id, cutover.reload.source_through_id
    assert_equal second.id, cutover.backfilled_through_id
    assert_equal 2, client.select("SELECT count() AS count FROM heartbeats FINAL").sole.fetch("count").to_i

    invoke_task("drain_outbox")
    invoke_task("verify")
    assert_equal second.id, cutover.reload.verified_through_id
    assert_predicate cutover, :verified_at?

    late = Heartbeat.create!(user:, time: started_at + 60, entity: "late.rb", source_type: :direct_entry)
    Rake::Task["clickhouse:verify"].reenable
    _output, error_output = capture_io do
      error = assert_raises(SystemExit) { Rake::Task["clickhouse:verify"].invoke }
      assert_equal 1, error.status
    end
    assert_includes error_output, "PostgreSQL received heartbeats after the recorded source boundary"

    late.destroy!
    user.update!(dashboard_rollup_generation: 4, dashboard_rollup_refreshed_generation: 3)
    ENV["HEARTBEAT_STORE"] = "clickhouse"
    ENV["CLICKHOUSE_TEST"] = "1"
    output, = invoke_task("purge_postgres")

    assert_includes output, "Removed all PostgreSQL heartbeat payloads and dashboard rollups"
    assert_equal 0, Heartbeat.postgresql_unscoped.count
    assert_predicate cutover.reload, :purged_at?
    assert_equal [ 0, 0 ], user.reload.values_at(:dashboard_rollup_generation, :dashboard_rollup_refreshed_generation)
  end

  test "recovery replays completed lifecycle controls over a stale ClickHouse restore" do
    require_clickhouse_integration!

    setup_clickhouse_database
    ENV["HEARTBEAT_STORE"] = "clickhouse"
    ENV["CLICKHOUSE_TEST"] = "1"
    ENV.delete("HEARTBEAT_MUTATIONS_STOPPED")
    ENV.delete("HEARTBEAT_WRITES_STOPPED")
    repository = HeartbeatRepository.current
    started_at = Time.utc(2026, 8, 12, 12).to_f

    transfer_source = User.create!(timezone: "UTC")
    transfer_target = User.create!(timezone: "UTC")
    transfer_final_target = User.create!(timezone: "UTC")
    deletion_before_nullification = User.create!(timezone: "UTC")
    nullification_before_deletion = User.create!(timezone: "UTC")
    later_ja4 = Ja4.create!(fingerprint: SecureRandom.hex(18))
    earlier_ja4 = Ja4.create!(fingerprint: SecureRandom.hex(18))

    ingest_heartbeat(repository, transfer_source, "transfer.rb", started_at, ja4: later_ja4)
    ingest_heartbeat(repository, deletion_before_nullification, "delete-then-ja4.rb", started_at + 1, ja4: later_ja4)
    ingest_heartbeat(repository, nullification_before_deletion, "ja4-then-delete.rb", started_at + 2, ja4: earlier_ja4)

    payload_tables = %w[heartbeat_store heartbeat_aliases heartbeats heartbeats_by_time]
    payload_tables.each do |table|
      @client.execute("CREATE TABLE recovery_backup_#{table} AS #{table}")
      @client.execute("INSERT INTO recovery_backup_#{table} SELECT * FROM #{table}")
    end

    transfer = repository.prepare_transfer(from_user_id: transfer_source.id, to_user_id: transfer_target.id)
    repository.transfer_rows(transfer)
    transfer.update!(status: :completed, completed_at: Time.current)
    chained_transfer = repository.prepare_transfer(
      from_user_id: transfer_target.id,
      to_user_id: transfer_final_target.id
    )
    repository.transfer_rows(chained_transfer)
    chained_transfer.update!(status: :completed, completed_at: Time.current)

    earlier_nullification = HeartbeatJa4Nullification.create!(ja4_id: earlier_ja4.id)
    repository.nullify_ja4(earlier_ja4.id, version: earlier_nullification.clickhouse_version)
    earlier_nullification.update!(completed_at: Time.current)
    later_deletion = HeartbeatDeletion.create!(user_id: nullification_before_deletion.id)
    repository.soft_delete_user(
      later_deletion.user_id,
      version: later_deletion.clickhouse_version,
      deleted_at: later_deletion.created_at
    )
    later_deletion.update!(status: :completed, completed_at: Time.current)

    earlier_deletion = HeartbeatDeletion.create!(user_id: deletion_before_nullification.id)
    repository.soft_delete_user(
      earlier_deletion.user_id,
      version: earlier_deletion.clickhouse_version,
      deleted_at: earlier_deletion.created_at
    )
    earlier_deletion.update!(status: :completed, completed_at: Time.current)
    later_nullification = HeartbeatJa4Nullification.create!(ja4_id: later_ja4.id)
    repository.nullify_ja4(later_ja4.id, version: later_nullification.clickhouse_version)
    later_nullification.update!(completed_at: Time.current)

    payload_tables.each do |table|
      @client.execute("TRUNCATE TABLE #{table}")
      @client.execute("INSERT INTO #{table} SELECT * FROM recovery_backup_#{table}")
    end
    assert_equal 1, repository.for_user(transfer_source.id).count
    assert_equal 1, repository.for_user(deletion_before_nullification.id).count
    assert_equal 1, repository.for_user(nullification_before_deletion.id).count

    max_id = @client.select("SELECT max(id) AS value FROM heartbeat_store").sole.fetch("value").to_i
    max_version = @client.select(<<~SQL.squish).sole.fetch("value").to_i
      SELECT greatest(max(version), max(store_version), max(heartbeats_version),
        max(heartbeats_by_time_version), max(ja4_nullification_version)) AS value
      FROM heartbeat_store
    SQL
    connection = ActiveRecord::Base.connection
    connection.execute("SELECT setval('heartbeat_id_allocations_id_seq', 1, true)")
    connection.execute("SELECT setval('heartbeat_clickhouse_versions_id_seq', 1, true)")

    ENV["HEARTBEAT_WRITES_STOPPED"] = "1"
    ENV["HEARTBEAT_MUTATIONS_STOPPED"] = "1"
    2.times { invoke_task("replay_lifecycle_controls") }

    assert_operator repository.next_id, :>, max_id
    assert_operator repository.next_version, :>, max_version

    assert_equal 0, repository.for_user(transfer_source.id).count
    assert_equal 0, repository.for_user(transfer_target.id).count
    assert_equal 1, repository.for_user(transfer_final_target.id).count
    assert_equal 0, repository.for_user(transfer_final_target.id).where.not(ja4_id: nil).count
    [ deletion_before_nullification, nullification_before_deletion ].each do |user|
      assert_equal 0, repository.for_user(user.id).count
      assert_equal 1, repository.for_user(user.id).with_deleted.count
      assert_equal 0, repository.for_user(user.id).with_deleted.where.not(ja4_id: nil).count
    end
  end

  private

  def setup_clickhouse_database
    @admin = @previous_client || ClickHouse::Client.new(@previous_clickhouse_url)
    @database = "hackatime_cutover_test_#{Process.pid}_#{SecureRandom.hex(4)}"
    @admin.execute("CREATE DATABASE #{@database}")
    @client = ClickHouse::Client.new(@previous_clickhouse_url.sub(%r{/[^/]+\z}, "/#{@database}"))
    ClickHouse::Client.instance_variable_set(:@current, @client)
    HeartbeatRepository.instance_variable_set(:@current, HeartbeatRepository.new(client: @client))
    ENV["CLICKHOUSE_URL"] = @previous_clickhouse_url.sub(%r{/[^/]+\z}, "/#{@database}")
    ENV["CLICKHOUSE_TEST"] = "0"
    invoke_task("migrate")
  end

  def ingest_heartbeat(repository, user, entity, time, ja4: nil)
    result = HeartbeatIngest.call(
      user:,
      mode: :direct,
      heartbeats: [ { entity:, time:, type: "file" } ],
      request_context: ja4 ? { ja4: ja4.fingerprint } : {},
      schedule_rollup_refresh: false
    )
    assert_equal 1, result.persisted_count
    repository.for_user(user.id).sole
  end

  def invoke_task(name)
    Rake::Task["clickhouse:#{name}"].reenable
    capture_io { Rake::Task["clickhouse:#{name}"].invoke }
  end

  def restore_env(name, value)
    value ? ENV[name] = value : ENV.delete(name)
  end
end
