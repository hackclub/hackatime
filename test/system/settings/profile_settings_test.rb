require "application_system_test_case"
require_relative "test_helpers"

class ProfileSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  test "default settings route renders profile settings page" do
    visit my_settings_path

    assert_current_path my_settings_path, ignore_query: true
    assert_text "Settings"
    assert_text "Region and Timezone"
    assert_text "Email Addresses"
    assert_selector "[data-settings-card]", minimum: 3
  end

  test "settings hash redirects to the matching settings page and subsection" do
    visit "#{my_settings_profile_path}#user_api_key"

    assert_current_path my_settings_privacy_path, ignore_query: true
    assert_text "API Key"
    assert_selector "[data-settings-subnav-item][data-active='true']", text: "API key"
  end

  test "profile settings updates country and username" do
    @user.update!(country_code: "CA", username: "old_name")
    new_username = "settings_#{SecureRandom.hex(4)}"
    country_name = ISO3166::Country["US"].common_name

    visit my_settings_profile_path

    choose_select_option("country_code", country_name)
    click_on "Save region settings"
    assert_text "Settings updated successfully"
    assert_equal "US", @user.reload.country_code

    fill_in "Username", with: new_username
    click_on "Save username"
    assert_text "Settings updated successfully"
    assert_equal new_username, @user.reload.username
    assert_equal "US", @user.reload.country_code
  end

  test "profile settings rejects invalid username" do
    @user.update!(username: "good_name")

    visit my_settings_profile_path
    fill_in "Username", with: "bad username!"
    click_on "Save username"

    assert_text "Some changes could not be saved:"
    assert_text "Username may only include letters, numbers, '-', and '_'"
    assert_equal "good_name", @user.reload.username
  end
end
