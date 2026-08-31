require "test_helper"

class SettingsImportsExportsControllerTest < ActionDispatch::IntegrationTest
  test "deferred data export reload does not clobber user props" do
    user = create(:user)
    sign_in_as(user)

    get my_settings_imports_exports_path
    inertia_reload_only :data_export

    assert_response :success
    assert_nil inertia.props["user"]
    assert_equal false, inertia.props.dig("data_export", "is_restricted")
  end

  test "imports & exports page omits remote cooldown for superadmins" do
    user = create(:user, :superadmin)
    sign_in_as(user)

    create(:heartbeat_import_run,
      user: user,
      source_kind: :wakatime_dump,
      state: :completed,
      encrypted_api_key: "secret",
      remote_requested_at: 1.minute.ago
    )

    get my_settings_imports_exports_path

    assert_response :success
    assert_equal My::HeartbeatsController::EXPORT_COOLDOWN.in_minutes.to_i,
      inertia.props["export_cooldown_minutes"]
    assert_nil inertia.props["remote_import_cooldown_until"]
    assert_nil inertia.props.dig("latest_heartbeat_import", "cooldown_until")
  end

  test "imports & exports page refreshes stale remote imports" do
    user = create(:user)
    sign_in_as(user)

    run = create(:heartbeat_import_run,
      user: user,
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
      get my_settings_imports_exports_path
    ensure
      singleton_class.alias_method :refresh_remote_run!, :__original_refresh_remote_run_for_test
      singleton_class.remove_method :__original_refresh_remote_run_for_test
    end

    assert_response :success
    assert_inertia_component "Users/Settings/ImportsExports"
    latest_import = inertia.props["latest_heartbeat_import"]
    assert_equal run.id.to_s, latest_import["import_id"]
    assert_equal "Completed", latest_import["remote_dump_status"]
    assert_equal "Downloading data dump...", latest_import["message"]
  end
end
