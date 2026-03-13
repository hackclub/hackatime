require "application_system_test_case"
require_relative "test_helpers"

class DataSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  teardown do
    Flipper.disable(:imports)
  end

  test "data settings page renders key sections" do
    Flipper.enable_actor(:imports, @user)

    assert_settings_page(
      path: my_settings_data_path,
      marker_text: "Imports",
      card_count: 3
    )

    assert_text "Download Data"
    assert_button "Export all heartbeats"
    assert_button "Export date range"
    assert_text "Account Deletion"
    assert_button "Request deletion"
  end

  test "data settings restricts exports for red trust users" do
    @user.update!(trust_level: :red)

    visit my_settings_data_path

    assert_text "Data export is currently restricted for this account."
    assert_no_button "Export all heartbeats"
    assert_no_button "Export date range"
  end

  test "data settings redirects to deletion page when request already exists" do
    DeletionRequest.create_for_user!(@user)

    visit my_settings_data_path

    assert_current_path deletion_path, ignore_query: true
    assert_text "Account Scheduled for Deletion"
    assert_text "I changed my mind"
  end

  test "imports card is visible when feature is enabled for the user" do
    Flipper.enable_actor(:imports, @user)

    visit my_settings_data_path

    assert_text "Imports"
    assert_text "WakaTime"
    assert_text "Hackatime v1"
    assert_field "remote_import_api_key"
    assert_text "Start remote import"
  end

  test "imports card is hidden when feature is disabled" do
    visit my_settings_data_path

    assert_no_text "Request a one-time heartbeat dump from WakaTime or legacy Hackatime."
    assert_no_field "remote_import_api_key"
    assert_no_button "Start remote import"
  end

  test "data settings shows remote import cooldown notice" do
    Flipper.enable_actor(:imports, @user)

    @user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :waiting_for_dump,
      encrypted_api_key: "secret",
      remote_requested_at: 1.minute.ago,
      message: "Waiting..."
    )

    visit my_settings_data_path

    assert_text "Remote imports can be started again after"
  end
end
