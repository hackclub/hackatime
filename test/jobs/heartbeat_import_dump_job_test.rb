require "test_helper"

class HeartbeatImportDumpJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    Flipper.disable(:imports)
    ActiveJob::Base.queue_adapter = @original_queue_adapter
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "requests a remote dump and schedules polling" do
    user = User.create!(timezone: "UTC")
    Flipper.enable_actor(:imports, user)
    run = user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :queued,
      encrypted_api_key: "secret"
    )

    fake_client = Object.new
    fake_client.define_singleton_method(:request_dump) do
      {
        id: "dump-123",
        status: "Pending",
        percent_complete: 12.0,
        download_url: nil,
        type: "heartbeats",
        is_processing: true,
        is_stuck: false,
        has_failed: false
      }
    end

    with_dump_client(fake_client) do
      assert_enqueued_with(job: HeartbeatImportDumpJob) do
        HeartbeatImportDumpJob.perform_now(run.id)
      end
    end

    run.reload
    assert_equal "waiting_for_dump", run.state
    assert_equal "dump-123", run.remote_dump_id
    assert_not_nil run.remote_requested_at
  end

  test "downloads a completed dump and enqueues the import job" do
    user = User.create!(timezone: "UTC")
    Flipper.enable_actor(:imports, user)
    run = user.heartbeat_import_runs.create!(
      source_kind: :hackatime_v1_dump,
      state: :waiting_for_dump,
      encrypted_api_key: "secret",
      remote_dump_id: "dump-456",
      remote_requested_at: Time.current
    )

    fake_client = Object.new
    fake_client.define_singleton_method(:list_dumps) do
      [
        {
          id: "dump-456",
          status: "Completed",
          percent_complete: 100.0,
          download_url: "https://example.invalid/download.json",
          type: "heartbeats",
          is_processing: false,
          is_stuck: false,
          has_failed: false
        }
      ]
    end
    fake_client.define_singleton_method(:download_dump) do |_url|
      '{"heartbeats":[]}'
    end

    with_dump_client(fake_client) do
      assert_enqueued_with(job: HeartbeatImportJob) do
        HeartbeatImportDumpJob.perform_now(run.id)
      end
    end

    run.reload
    assert_equal "downloading_dump", run.state
  end

  test "marks the run as failed on authentication errors" do
    user = User.create!(timezone: "UTC")
    Flipper.enable_actor(:imports, user)
    run = user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :queued,
      encrypted_api_key: "secret"
    )

    fake_client = Object.new
    fake_client.define_singleton_method(:request_dump) do
      raise HeartbeatImportDumpClient::AuthenticationError, "Authentication failed (401)"
    end

    with_dump_client(fake_client) do
      HeartbeatImportDumpJob.perform_now(run.id)
    end

    run.reload
    assert_equal "failed", run.state
    assert_equal "Import failed: Authentication failed (401)", run.message
    assert_nil run.encrypted_api_key
  end

  private

  def with_dump_client(fake_client)
    singleton_class = HeartbeatImportDumpClient.singleton_class
    singleton_class.alias_method :__original_new_for_test, :new
    singleton_class.define_method(:new) do |*|
      fake_client
    end
    yield
  ensure
    singleton_class.alias_method :new, :__original_new_for_test
    singleton_class.remove_method :__original_new_for_test
  end
end
