require "test_helper"

class SettingsNotificationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  test "notifications show renders notifications settings page" do
    user = users(:one)
    sign_in_as(user)

    get my_settings_notifications_path

    assert_response :success
    assert_inertia_component "Users/Settings/Notifications"
  end

  test "notifications update persists weekly summary email preference" do
    user = users(:one)
    sign_in_as(user)

    patch my_settings_notifications_path, params: { user: { weekly_summary_email_enabled: "0" } }

    assert_response :redirect
    assert_redirected_to my_settings_notifications_path
    assert_equal false, user.reload.weekly_summary_email_enabled
  end
end
