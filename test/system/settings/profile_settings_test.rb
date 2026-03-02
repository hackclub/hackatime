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
  end

  test "profile settings rejects invalid username" do
    @user.update!(username: "good_name")

    visit my_settings_profile_path
    fill_in "Username", with: "bad username!"
    click_on "Save username"

    assert_current_path my_settings_profile_path, ignore_query: true
    assert_text "Some changes could not be saved:"
    assert_text "Username may only include letters, numbers, '-', and '_'"
    assert_equal "good_name", @user.reload.username
  end

  test "profile settings updates privacy option" do
    @user.update!(allow_public_stats_lookup: false)

    visit my_settings_profile_path

    within("#user_privacy") do
      find("[role='checkbox']").click
      click_on "Save privacy settings"
    end

    assert_text "Settings updated successfully"
    assert_equal true, @user.reload.allow_public_stats_lookup
  end

  test "profile settings updates theme" do
    @user.update!(theme: :gruvbox_dark)

    visit my_settings_profile_path

    within("#user_theme") do
      click_on "Neon"
      click_on "Save theme"
    end

    assert_text "Settings updated successfully"
    assert_equal "neon", @user.reload.theme
  end
end
