require "test_helper"

class My::HeartbeatImportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  fixtures :users

  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  teardown do
    Flipper.disable(:imports)
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "create rejects guests" do
    post my_heartbeat_imports_path

    assert_response :unauthorized
    assert_equal "You must be logged in to view this page.", JSON.parse(response.body)["error"]
  end

  test "create rejects dev upload outside development" do
    user = users(:one)
    sign_in_as(user)

    post my_heartbeat_imports_path, params: { heartbeat_file: uploaded_file }

    assert_response :forbidden
    assert_equal "Heartbeat import is only available in development.", JSON.parse(response.body)["error"]
  end

  test "create returns error when no import data is provided" do
    user = users(:one)
    sign_in_as(user)

    post my_heartbeat_imports_path

    assert_response :unprocessable_entity
    assert_equal "No import data provided.", JSON.parse(response.body)["error"]
  end

  test "create returns error when dev upload file type is invalid" do
    user = users(:one)
    sign_in_as(user)

    with_development_env do
      post my_heartbeat_imports_path, params: {
        heartbeat_file: uploaded_file(filename: "heartbeats.txt", content_type: "text/plain", content: "hello")
      }
    end

    assert_response :unprocessable_entity
    assert_equal "pls upload only json (download from the button above it)", JSON.parse(response.body)["error"]
  end

  test "create starts dev upload import" do
    user = users(:one)
    sign_in_as(user)

    with_development_env do
      assert_difference -> { user.heartbeat_import_runs.count }, +1 do
        assert_enqueued_with(job: HeartbeatImportJob) do
          post my_heartbeat_imports_path, params: { heartbeat_file: uploaded_file }
        end
      end
    end

    assert_response :accepted
    body = JSON.parse(response.body)
    assert body["import_id"].present?
    assert_equal "queued", body.dig("status", "state")
    assert_equal "dev_upload", body.dig("status", "source_kind")
  end

  test "remote create rejects users without the imports feature" do
    user = users(:one)
    sign_in_as(user)

    post my_heartbeat_imports_path, params: remote_params(provider: "wakatime_dump")

    assert_response :not_found
    assert_equal "Imports are not enabled for this user.", JSON.parse(response.body)["error"]
  end

  test "remote create rejects during cooldown" do
    user = users(:one)
    sign_in_as(user)
    Flipper.enable_actor(:imports, user)

    user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :completed,
      encrypted_api_key: "old-secret",
      remote_requested_at: 1.hour.ago
    )

    post my_heartbeat_imports_path, params: remote_params(provider: "wakatime_dump")

    assert_response :too_many_requests
    assert_equal "Remote imports are limited to once every 4 hours.", JSON.parse(response.body)["error"]
  end

  test "remote create rejects when another import is active" do
    user = users(:one)
    sign_in_as(user)
    Flipper.enable_actor(:imports, user)

    user.heartbeat_import_runs.create!(
      source_kind: :dev_upload,
      state: :queued,
      source_filename: "old.json"
    )

    post my_heartbeat_imports_path, params: remote_params(provider: "wakatime_dump")

    assert_response :conflict
    assert_equal "Another import is already in progress.", JSON.parse(response.body)["error"]
  end

  test "remote create starts wakatime import" do
    user = users(:one)
    sign_in_as(user)
    Flipper.enable_actor(:imports, user)

    assert_difference -> { user.heartbeat_import_runs.count }, +1 do
      assert_enqueued_with(job: HeartbeatImportDumpJob) do
        post my_heartbeat_imports_path, params: remote_params(provider: "wakatime_dump")
      end
    end

    assert_response :accepted
    body = JSON.parse(response.body)
    assert_equal "wakatime_dump", body.dig("status", "source_kind")
    assert_equal "queued", body.dig("status", "state")
  end

  test "remote create starts hackatime v1 import" do
    user = users(:one)
    sign_in_as(user)
    Flipper.enable_actor(:imports, user)

    assert_difference -> { user.heartbeat_import_runs.count }, +1 do
      assert_enqueued_with(job: HeartbeatImportDumpJob) do
        post my_heartbeat_imports_path, params: remote_params(provider: "hackatime_v1_dump")
      end
    end

    assert_response :accepted
    body = JSON.parse(response.body)
    assert_equal "hackatime_v1_dump", body.dig("status", "source_kind")
    assert_equal "queued", body.dig("status", "state")
  end

  test "show returns status for existing import" do
    user = users(:one)
    sign_in_as(user)

    run = user.heartbeat_import_runs.create!(
      source_kind: :dev_upload,
      state: :completed,
      source_filename: "heartbeats.json",
      imported_count: 4,
      total_count: 5,
      skipped_count: 1,
      message: "Completed."
    )

    get my_heartbeat_import_path(run)

    assert_response :success
    assert_equal run.id.to_s, JSON.parse(response.body).fetch("import_id")
  end

  test "show refreshes stale remote imports" do
    user = users(:one)
    sign_in_as(user)
    Flipper.enable_actor(:imports, user)

    run = user.heartbeat_import_runs.create!(
      source_kind: :hackatime_v1_dump,
      state: :waiting_for_dump,
      encrypted_api_key: "secret",
      remote_dump_id: "dump-123",
      remote_requested_at: 10.minutes.ago,
      remote_dump_status: "Pending…",
      message: "Pending…..."
    )
    run.update_column(:updated_at, 10.seconds.ago)

    singleton_class = HeartbeatImportRunner.singleton_class
    singleton_class.alias_method :__original_refresh_remote_run_for_test, :refresh_remote_run!
    singleton_class.define_method(:refresh_remote_run!) do |stale_run|
      stale_run.update!(
        remote_dump_status: "Completed",
        message: "Downloading data dump..."
      )
      stale_run.reload
    end

    begin
      get my_heartbeat_import_path(run)
    ensure
      singleton_class.alias_method :refresh_remote_run!, :__original_refresh_remote_run_for_test
      singleton_class.remove_method :__original_refresh_remote_run_for_test
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Completed", body["remote_dump_status"]
    assert_equal "Downloading data dump...", body["message"]
  end

  test "show returns not found for another user's import" do
    user = users(:one)
    other_user = users(:two)
    sign_in_as(user)

    run = other_user.heartbeat_import_runs.create!(
      source_kind: :dev_upload,
      state: :queued,
      source_filename: "other.json"
    )

    get my_heartbeat_import_path(run)

    assert_response :not_found
    assert_equal "Import not found", JSON.parse(response.body)["error"]
  end

  private

  def with_development_env
    rails_singleton = class << Rails; self; end
    rails_singleton.alias_method :__original_env_for_test, :env
    rails_singleton.define_method(:env) { ActiveSupport::StringInquirer.new("development") }
    yield
  ensure
    rails_singleton.remove_method :env
    rails_singleton.alias_method :env, :__original_env_for_test
    rails_singleton.remove_method :__original_env_for_test
  end

  def uploaded_file(filename: "heartbeats.json", content_type: "application/json", content: '{"heartbeats":[]}')
    Rack::Test::UploadedFile.new(
      StringIO.new(content),
      content_type,
      original_filename: filename
    )
  end

  def remote_params(provider:)
    {
      heartbeat_import: {
        provider: provider,
        api_key: "remote-key-#{SecureRandom.hex(8)}"
      }
    }
  end
end
