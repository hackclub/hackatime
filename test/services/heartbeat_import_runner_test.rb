require "test_helper"

class HeartbeatImportRunnerTest < ActiveSupport::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    ActionMailer::Base.deliveries.clear
  end

  test "run_import emails the user when a wakatime import succeeds" do
    user = User.create!(timezone: "UTC")
    user.email_addresses.create!(email: "success-#{SecureRandom.hex(4)}@example.com", source: :signing_in)
    run = user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :queued,
      encrypted_api_key: "secret"
    )

    file = Tempfile.new([ "heartbeats", ".json" ])
    file.write(
      {
        heartbeats: [
          {
            entity: "/tmp/test.rb",
            type: "file",
            time: 1_700_000_000.0,
            project: "hackatime",
            language: "Ruby",
            is_write: true
          }
        ]
      }.to_json
    )
    file.close

    HeartbeatImportRunner.run_import(import_run_id: run.id, file_path: file.path)

    run.reload
    assert_equal "completed", run.state
    assert_nil run.encrypted_api_key
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal "Your WakaTime import is complete", ActionMailer::Base.deliveries.last.subject
  ensure
    file&.unlink
  end

  test "run_import does not overwrite a completed run if completion follow-up fails" do
    user = User.create!(timezone: "UTC")
    user.email_addresses.create!(email: "post-complete-#{SecureRandom.hex(4)}@example.com", source: :signing_in)
    run = user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :queued,
      encrypted_api_key: "secret"
    )

    file = Tempfile.new([ "heartbeats", ".json" ])
    file.write(
      {
        heartbeats: [
          {
            entity: "/tmp/test.rb",
            type: "file",
            time: 1_700_000_000.0,
            project: "hackatime",
            language: "Ruby",
            is_write: true
          }
        ]
      }.to_json
    )
    file.close

    singleton_class = HeartbeatImportRunner.singleton_class
    singleton_class.alias_method :__original_send_completion_email_for_test, :send_completion_email
    singleton_class.define_method(:send_completion_email) do |_completed_run|
      raise "mail transport failed"
    end

    begin
      HeartbeatImportRunner.run_import(import_run_id: run.id, file_path: file.path)
    ensure
      singleton_class.alias_method :send_completion_email, :__original_send_completion_email_for_test
      singleton_class.remove_method :__original_send_completion_email_for_test
      file&.unlink
    end

    run.reload
    assert_equal "completed", run.state
    assert_nil run.error_message
    assert_nil run.encrypted_api_key
    assert_empty ActionMailer::Base.deliveries
  end

  test "fail_run_for_error! emails the user about invalid api keys" do
    user = User.create!(timezone: "UTC")
    user.email_addresses.create!(email: "invalid-key-#{SecureRandom.hex(4)}@example.com", source: :signing_in)
    run = user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :queued,
      encrypted_api_key: "secret"
    )

    HeartbeatImportRunner.fail_run_for_error!(
      import_run_id: run.id,
      error: HeartbeatImportDumpClient::AuthenticationError.new("Authentication failed (401)", status: 401)
    )

    run.reload
    assert_equal "failed", run.state
    assert_equal "WakaTime rejected the import because the API key is invalid.", run.error_message
    assert_nil run.encrypted_api_key
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal "Your WakaTime import failed", ActionMailer::Base.deliveries.last.subject
  end

  test "fail_run_for_error! includes slack guidance for hackatime v1 provider errors" do
    user = User.create!(timezone: "UTC")
    user.email_addresses.create!(email: "provider-error-#{SecureRandom.hex(4)}@example.com", source: :signing_in)
    run = user.heartbeat_import_runs.create!(
      source_kind: :hackatime_v1_dump,
      state: :queued,
      encrypted_api_key: "secret"
    )

    HeartbeatImportRunner.fail_run_for_error!(
      import_run_id: run.id,
      error: HeartbeatImportDumpClient::TransientError.new("Request failed with status 500", status: 500)
    )

    run.reload
    assert_equal "failed", run.state
    assert_equal "Hackatime v1 ran into an error while processing the import. Please reach out to #hackatime-help on Slack.", run.error_message
    assert_nil run.encrypted_api_key
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal "Your Hackatime v1 import failed", ActionMailer::Base.deliveries.last.subject
  end

  test "start_remote_import bypasses cooldown for superadmins" do
    user = User.create!(timezone: "UTC", admin_level: :superadmin)
    Flipper.enable_actor(:imports, user)

    user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :completed,
      encrypted_api_key: "old-secret",
      remote_requested_at: 1.minute.ago
    )

    assert_difference -> { user.heartbeat_import_runs.count }, +1 do
      run = HeartbeatImportRunner.start_remote_import(
        user: user,
        provider: "wakatime_dump",
        api_key: "new-secret"
      )

      assert_equal "wakatime_dump", run.source_kind
      assert_equal "queued", run.state
    end
  end

  test "serialize omits cooldown for superadmins" do
    user = User.create!(timezone: "UTC", admin_level: :superadmin)
    run = user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :completed,
      encrypted_api_key: "secret",
      remote_requested_at: 1.minute.ago
    )

    payload = HeartbeatImportRunner.serialize(run)

    assert_nil payload[:cooldown_until]
  end

  test "refreshable_remote_run? stops once a remote import is downloading or importing" do
    user = User.create!(timezone: "UTC")
    Flipper.enable_actor(:imports, user)

    %i[downloading_dump importing].each do |state|
      run = user.heartbeat_import_runs.create!(
        source_kind: :wakatime_dump,
        state: state,
        encrypted_api_key: "secret"
      )
      run.update_column(:updated_at, 10.seconds.ago)

      assert_not HeartbeatImportRunner.refreshable_remote_run?(run)
    end
  end
end
