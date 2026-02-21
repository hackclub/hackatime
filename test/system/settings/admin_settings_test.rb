require "application_system_test_case"
require_relative "test_helpers"

class AdminSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  test "admin settings redirects non-admin users" do
    visit my_settings_admin_path

    assert_current_path my_settings_profile_path, ignore_query: true
    assert_text "You are not authorized to access this page"
  end

  test "admin settings can add and delete mirror endpoint" do
    @user.update!(admin_level: :admin)

    visit my_settings_admin_path
    assert_text "WakaTime Mirrors"

    endpoint_url = "https://example-wakatime.invalid/api/v1"

    fill_in "Endpoint URL", with: endpoint_url
    fill_in "WakaTime API Key", with: "mirror-key-#{SecureRandom.hex(8)}"

    assert_difference -> { @user.reload.wakatime_mirrors.count }, +1 do
      click_on "Add mirror"
      assert_text "WakaTime mirror added successfully"
    end

    visit my_settings_admin_path
    assert_text endpoint_url

    click_on "Delete"
    within_modal do
      click_on "Delete mirror"
    end

    assert_text "WakaTime mirror removed successfully"
    assert_equal 0, @user.reload.wakatime_mirrors.count
  end

  test "admin settings rejects hackatime mirror endpoint" do
    @user.update!(admin_level: :admin)

    visit my_settings_admin_path

    fill_in "Endpoint URL", with: "https://hackatime.hackclub.com/api/v1"
    fill_in "WakaTime API Key", with: "mirror-key-#{SecureRandom.hex(8)}"
    click_on "Add mirror"

    assert_text "cannot be hackatime.hackclub.com"
    assert_equal 0, @user.reload.wakatime_mirrors.count
  end
end
