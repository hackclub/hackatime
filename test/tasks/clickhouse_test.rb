require "test_helper"
require "rake"

Rails.application.load_tasks unless Rake::Task.task_defined?("clickhouse:purge_postgres")

class ClickhouseTaskTest < ActiveSupport::TestCase
  setup do
    @previous_store = ENV["HEARTBEAT_STORE"]
    @previous_writes_stopped = ENV["HEARTBEAT_WRITES_STOPPED"]
    @previous_clickhouse_test = ENV["CLICKHOUSE_TEST"]
    @previous_clickhouse_url = ENV["CLICKHOUSE_URL"]
    @previous_batch_size = ENV["BATCH_SIZE"]
    @previous_client = ClickHouse::Client.instance_variable_get(:@current)
    @previous_repository = HeartbeatRepository.instance_variable_get(:@current)
  end

  teardown do
    @admin&.execute("DROP DATABASE IF EXISTS #{@database}") if @database
    restore_env("HEARTBEAT_STORE", @previous_store)
    restore_env("HEARTBEAT_WRITES_STOPPED", @previous_writes_stopped)
    restore_env("CLICKHOUSE_TEST", @previous_clickhouse_test)
    restore_env("CLICKHOUSE_URL", @previous_clickhouse_url)
    restore_env("BATCH_SIZE", @previous_batch_size)
    ClickHouse::Client.instance_variable_set(:@current, @previous_client)
    HeartbeatRepository.instance_variable_set(:@current, @previous_repository)
    %w[migrate backfill verify drain_outbox purge_postgres].each do |task|
      Rake::Task["clickhouse:#{task}"].reenable
    end
  end

  test "PostgreSQL purge requires the application write fence" do
    ENV["HEARTBEAT_STORE"] = "clickhouse"
    ENV.delete("HEARTBEAT_WRITES_STOPPED")

    error = assert_raises(SystemExit) { capture_io { Rake::Task["clickhouse:purge_postgres"].invoke } }
    assert_equal 1, error.status
  end

  test "two-pass backfill verifies the fenced PostgreSQL boundary" do
    skip "Set CLICKHOUSE_INTEGRATION=1 to run" unless ENV["CLICKHOUSE_INTEGRATION"] == "1"

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
    ENV.delete("HEARTBEAT_WRITES_STOPPED")

    invoke_task("migrate")
    user = User.create!(timezone: "UTC")
    first = Heartbeat.create!(user:, time: Time.current.to_f, entity: "first.rb", source_type: :direct_entry)

    invoke_task("backfill")
    cutover = HeartbeatCutover.find(1)
    assert_equal first.id, cutover.source_through_id
    assert_equal first.id, cutover.backfilled_through_id
    assert_equal 1, client.select("SELECT count() AS count FROM heartbeats FINAL").sole.fetch("count").to_i

    second = Heartbeat.create!(user:, time: Time.current.to_f + 30, entity: "second.rb", source_type: :direct_entry)
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

    Heartbeat.create!(user:, time: Time.current.to_f + 60, entity: "late.rb", source_type: :direct_entry)
    Rake::Task["clickhouse:verify"].reenable
    _output, error_output = capture_io do
      error = assert_raises(SystemExit) { Rake::Task["clickhouse:verify"].invoke }
      assert_equal 1, error.status
    end
    assert_includes error_output, "PostgreSQL received heartbeats after the recorded source boundary"
  end

  private

  def invoke_task(name)
    Rake::Task["clickhouse:#{name}"].reenable
    capture_io { Rake::Task["clickhouse:#{name}"].invoke }
  end

  def restore_env(name, value)
    value ? ENV[name] = value : ENV.delete(name)
  end
end
