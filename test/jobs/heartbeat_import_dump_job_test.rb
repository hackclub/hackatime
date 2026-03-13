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
    ActionMailer::Base.deliveries.clear
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

    payload = dump_payload(id: "dump-123", status: "Pending", percent_complete: 12.0)
    fake_client = Object.new
    fake_client.define_singleton_method(:request_dump) do
      payload
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

  test "downloads a completed dump and enqueues the shared download job" do
    user = User.create!(timezone: "UTC")
    Flipper.enable_actor(:imports, user)
    run = user.heartbeat_import_runs.create!(
      source_kind: :hackatime_v1_dump,
      state: :waiting_for_dump,
      encrypted_api_key: "secret",
      remote_dump_id: "dump-456",
      remote_requested_at: Time.current
    )

    payload = dump_payload(
      id: "dump-456",
      status: "Completed",
      percent_complete: 100.0,
      download_url: "https://example.invalid/download.json",
      is_processing: false
    )
    fake_client = Object.new
    fake_client.define_singleton_method(:list_dumps) do
      [ payload ]
    end
    with_dump_client(fake_client) do
      assert_enqueued_with(job: HeartbeatImportRemoteDownloadJob, args: [ run.id, "https://example.invalid/download.json" ]) do
        HeartbeatImportDumpJob.perform_now(run.id)
      end
    end

    run.reload
    assert_equal "downloading_dump", run.state
  end

  test "re-enqueues polling while the remote dump is still processing" do
    user = User.create!(timezone: "UTC")
    Flipper.enable_actor(:imports, user)
    run = user.heartbeat_import_runs.create!(
      source_kind: :hackatime_v1_dump,
      state: :waiting_for_dump,
      encrypted_api_key: "secret",
      remote_dump_id: "dump-456",
      remote_requested_at: Time.current
    )

    payload = dump_payload(id: "dump-456")
    fake_client = Object.new
    fake_client.define_singleton_method(:list_dumps) do
      [ payload ]
    end

    with_dump_client(fake_client) do
      assert_enqueued_with(job: HeartbeatImportDumpJob) do
        HeartbeatImportDumpJob.perform_now(run.id)
      end
    end

    run.reload
    assert_equal "waiting_for_dump", run.state
    assert_equal "Pending…...", run.message
  end

  test "fails the run when dump polling exceeds the timeout window" do
    user = User.create!(timezone: "UTC")
    user.email_addresses.create!(email: "timeout-#{SecureRandom.hex(4)}@example.com", source: :signing_in)
    Flipper.enable_actor(:imports, user)
    run = user.heartbeat_import_runs.create!(
      source_kind: :hackatime_v1_dump,
      state: :waiting_for_dump,
      encrypted_api_key: "secret",
      remote_dump_id: "dump-456",
      remote_requested_at: 31.minutes.ago
    )

    payload = dump_payload(id: "dump-456")
    fake_client = Object.new
    fake_client.define_singleton_method(:list_dumps) do
      [ payload ]
    end

    with_dump_client(fake_client) do
      HeartbeatImportDumpJob.perform_now(run.id)
    end

    run.reload
    assert_equal "failed", run.state
    assert_equal "Import failed: Data dump did not complete within 30 minutes.", run.message
  end

  test "marks the run as failed on authentication errors" do
    user = User.create!(timezone: "UTC")
    user.email_addresses.create!(email: "auth-#{SecureRandom.hex(4)}@example.com", source: :signing_in)
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
    assert_equal "Import failed: WakaTime rejected the import because the API key is invalid.", run.message
    assert_nil run.encrypted_api_key
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal "Your WakaTime import failed", ActionMailer::Base.deliveries.last.subject
  end

  test "emails the user when wakatime requires a manual download link" do
    user = User.create!(timezone: "UTC")
    user.email_addresses.create!(email: "manual-#{SecureRandom.hex(4)}@example.com", source: :signing_in)
    Flipper.enable_actor(:imports, user)
    run = user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :queued,
      encrypted_api_key: "secret"
    )

    fake_client = Object.new
    fake_client.define_singleton_method(:request_dump) do
      raise HeartbeatImportDumpClient::ManualDownloadLinkRequiredError, "WakaTime requires a recent export download link."
    end

    with_dump_client(fake_client) do
      HeartbeatImportDumpJob.perform_now(run.id)
    end

    run.reload
    assert_equal "failed", run.state
    assert_equal "WakaTime needs a recent export download link. Check your email for the next step.", run.error_message
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal "Your WakaTime import needs an export link", ActionMailer::Base.deliveries.last.subject
    assert_equal [ user.email_addresses.first.email ], ActionMailer::Base.deliveries.last.to
  end

  private

  def dump_payload(id:, status: "Pending…", percent_complete: 0.0, download_url: nil, is_processing: true)
    {
      id: id,
      status: status,
      percent_complete: percent_complete,
      download_url: download_url,
      type: "heartbeats",
      is_processing: is_processing,
      is_stuck: false,
      has_failed: false
    }
  end

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
