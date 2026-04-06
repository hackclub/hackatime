require "test_helper"

class SettingsProfileControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  test "settings page includes current username in layout nav props" do
    user = users(:one)
    user.update!(username: "profile_nav_user")
    sign_in_as(user)

    get my_settings_profile_path

    assert_response :success
    assert_equal "profile_nav_user", inertia_page.dig("props", "layout", "nav", "current_user", "username")
  end

  test "profile update persists selected theme" do
    user = users(:one)
    sign_in_as(user)

    patch my_settings_profile_path, params: { user: { theme: "nord" } }

    assert_response :redirect
    assert_redirected_to my_settings_profile_path
    assert_equal "nord", user.reload.theme
  end

  test "profile update normalizes blank country code to nil" do
    user = users(:one)
    user.update!(country_code: "US")
    sign_in_as(user)

    patch my_settings_profile_path, params: { user: { country_code: "" } }

    assert_response :redirect
    assert_nil user.reload.country_code
  end

  test "profile update with invalid username returns unprocessable entity" do
    user = users(:one)
    user.update!(username: "good_name")
    sign_in_as(user)

    patch my_settings_profile_path, params: { user: { username: "bad username!" } }

    assert_response :unprocessable_entity
    assert_inertia_component "Users/Settings/Profile"
  end
end
