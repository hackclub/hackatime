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

  test "notifications update subscribes user to weekly summary" do
    user = users(:one)
    user.unsubscribe("weekly_summary") if user.subscribed?("weekly_summary")
    sign_in_as(user)

    patch my_settings_notifications_path, params: { user: { weekly_summary_email_enabled: "1" } }

    assert_response :redirect
    assert_redirected_to my_settings_notifications_path
    assert user.reload.subscribed?("weekly_summary")
  end

  test "notifications update unsubscribes user from weekly summary" do
    user = users(:one)
    user.subscribe("weekly_summary") unless user.subscribed?("weekly_summary")
    sign_in_as(user)

    patch my_settings_notifications_path, params: { user: { weekly_summary_email_enabled: "0" } }

    assert_response :redirect
    assert_redirected_to my_settings_notifications_path
    assert_not user.reload.subscribed?("weekly_summary")
  end
end
