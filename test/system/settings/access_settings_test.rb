require "application_system_test_case"
require_relative "test_helpers"

class AccessSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = User.create!(timezone: "UTC")
    @user.api_keys.create!(name: "Initial key")
    sign_in_as(@user)
  end

  test "access settings page renders key sections" do
    assert_settings_page(
      path: my_settings_access_path,
      marker_text: "Time Tracking Setup"
    )

    assert_text "Extension Display"
    assert_text "API Key"
    assert_text "WakaTime Config File"
  end

  test "access settings updates extension display style" do
    visit my_settings_access_path

    choose_select_option("extension_type", "Clock emoji")
    click_on "Save extension settings"

    assert_text "Settings updated successfully"
    assert_equal "clock_emoji", @user.reload.hackatime_extension_text_type
  end

  test "access settings rotate api key can be canceled" do
    old_token = @user.api_keys.order(:id).last.token

    visit my_settings_access_path
    click_on "Rotate API key"
    assert_text "Rotate API key?"

    within_modal do
      click_on "Cancel"
    end

    assert_no_text(/New API key/i)
    assert_equal old_token, @user.reload.api_keys.order(:id).last.token
  end

  test "access settings rotates api key" do
    old_token = @user.api_keys.order(:id).last.token

    visit my_settings_access_path
    click_on "Rotate API key"

    within_modal do
      click_on "Rotate key"
    end

    assert_text(/New API key/i)

    new_token = @user.reload.api_keys.order(:id).last.token
    refute_equal old_token, new_token
    assert_equal 1, @user.api_keys.count
    assert_text new_token
  end
end
