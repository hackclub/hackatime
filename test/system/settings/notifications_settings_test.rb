require "application_system_test_case"
require_relative "test_helpers"

class NotificationsSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  test "notifications settings page renders weekly summary section" do
    assert_settings_page(
      path: my_settings_notifications_path,
      marker_text: "Email Notifications"
    )

    assert_text "Weekly coding summary email"
  end

  test "notifications settings updates weekly summary email preference" do
    @user.subscribe("weekly_summary")

    visit my_settings_notifications_path

    within("#user_weekly_summary_email") do
      find("[role='checkbox']", wait: 10).click
    end

    click_on "Save notification settings"

    assert_text "Settings updated successfully"
    assert_not @user.reload.subscribed?("weekly_summary")
  end
end
