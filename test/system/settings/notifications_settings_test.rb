require "application_system_test_case"

class NotificationsSettingsTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  test "notifications settings updates weekly summary email preference" do
    @user.subscribe("weekly_summary") unless @user.subscribed?("weekly_summary")

    visit my_settings_notifications_path

    within("#user_weekly_summary_email") do
      find("[role='checkbox']", wait: 10).click
    end

    click_on "Save notification settings"

    assert_text "Settings updated successfully"
    assert_not @user.reload.subscribed?("weekly_summary")
  end
end
