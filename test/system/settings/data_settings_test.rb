require "application_system_test_case"
require_relative "test_helpers"

class DataSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    Flipper.enable(:wakatime_imports_mirrors)
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  teardown do
    Flipper.disable(:wakatime_imports_mirrors)
  end

  test "data settings page renders key sections" do
    assert_settings_page(
      path: my_settings_data_path,
      marker_text: "Migration Assistant"
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

  test "regular user can add and delete mirror endpoint from data settings" do
    visit my_settings_data_path

    endpoint_url = "https://example-wakatime.invalid/api/v1"
    fill_in "mirror_endpoint_url", with: endpoint_url
    fill_in "mirror_key", with: "mirror-key-#{SecureRandom.hex(8)}"

    assert_difference -> { @user.reload.wakatime_mirrors.count }, +1 do
      click_on "Add mirror"
      assert_text "WakaTime mirror added successfully"
    end

    assert_text endpoint_url

    assert_difference -> { @user.reload.wakatime_mirrors.count }, -1 do
      accept_confirm do
        click_on "Delete mirror"
      end
      assert_text "WakaTime mirror removed successfully"
    end
  end

  test "data settings rejects hackatime mirror endpoint" do
    visit my_settings_data_path

    fill_in "mirror_endpoint_url", with: "https://hackatime.hackclub.com/api/v1"
    fill_in "mirror_key", with: "mirror-key-#{SecureRandom.hex(8)}"
    click_on "Add mirror"

    assert_text "cannot target this Hackatime host"
    assert_equal 0, @user.reload.wakatime_mirrors.count
  end

  test "data settings can configure import source and show status panel" do
    visit my_settings_data_path

    fill_in "import_endpoint_url", with: "https://wakatime.com/api/v1"
    fill_in "import_api_key", with: "import-key-#{SecureRandom.hex(8)}"

    assert_difference -> { HeartbeatImportSource.count }, +1 do
      click_on "Create source"
      assert_text "Import source configured successfully."
    end

    assert_text "Status:"
    assert_text "Imported:"
    assert_button "Sync now"
  end

  test "imports and mirrors section is hidden when feature is disabled" do
    Flipper.disable(:wakatime_imports_mirrors)

    visit my_settings_data_path

    assert_no_text "Imports & Mirrors"
    assert_no_field "mirror_endpoint_url"
    assert_no_field "import_endpoint_url"
  end
end
