require "application_system_test_case"
require_relative "test_helpers"

class ImportsExportsSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  teardown do
    Flipper.disable(:imports)
  end

  test "imports & exports page renders key sections" do
    Flipper.enable_actor(:imports, @user)

    assert_settings_page(
      path: my_settings_imports_exports_path,
      marker_text: "Imports",
      card_count: 2
    )

    assert_text "Download Data"
    assert_button "Export all heartbeats"
    assert_button "Export date range"
  end

  test "imports & exports page restricts exports for red trust users" do
    @user.update!(trust_level: :red)

    visit my_settings_imports_exports_path

    assert_text "Data export is currently restricted for this account."
    assert_no_button "Export all heartbeats"
    assert_no_button "Export date range"
  end

  test "imports card is visible when feature is enabled for the user" do
    Flipper.enable_actor(:imports, @user)

    visit my_settings_imports_exports_path

    assert_text "Imports"
    assert_text "WakaTime"
    assert_text "Hackatime v1"
    assert_field "remote_import_api_key"
    assert_text "Start remote import"
  end

  test "imports card is hidden when feature is disabled" do
    visit my_settings_imports_exports_path

    assert_no_text "Request a one-time heartbeat dump from WakaTime or legacy Hackatime."
    assert_no_field "remote_import_api_key"
    assert_no_button "Start remote import"
  end

  test "imports & exports page shows remote import cooldown notice" do
    Flipper.enable_actor(:imports, @user)

    @user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :waiting_for_dump,
      encrypted_api_key: "secret",
      remote_requested_at: 2.minutes.ago, # 2 min ago means cooldown has ~6 min left
      message: "Waiting..."
    )

    visit my_settings_imports_exports_path

    assert_text "Available again in"
  end
end
