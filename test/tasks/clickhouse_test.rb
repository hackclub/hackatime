require "test_helper"
require "rake"

Rails.application.load_tasks unless Rake::Task.task_defined?("clickhouse:purge_postgres")

class ClickhouseTaskTest < ActiveSupport::TestCase
  setup do
    @previous_store = ENV["HEARTBEAT_STORE"]
    @previous_writes_stopped = ENV["HEARTBEAT_WRITES_STOPPED"]
  end

  teardown do
    ENV["HEARTBEAT_STORE"] = @previous_store
    ENV["HEARTBEAT_WRITES_STOPPED"] = @previous_writes_stopped
    Rake::Task["clickhouse:purge_postgres"].reenable
  end

  test "PostgreSQL purge requires the application write fence" do
    ENV["HEARTBEAT_STORE"] = "clickhouse"
    ENV.delete("HEARTBEAT_WRITES_STOPPED")

    error = assert_raises(SystemExit) { capture_io { Rake::Task["clickhouse:purge_postgres"].invoke } }
    assert_equal 1, error.status
  end
end
