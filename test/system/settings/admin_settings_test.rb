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

  test "admin settings page is available to admin users" do
    @user.update!(admin_level: :admin)

    visit my_settings_admin_path
    assert_text "Mirror and import controls are available under Data settings for all users."
  end
end
