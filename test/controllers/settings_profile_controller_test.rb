require "test_helper"

class SettingsProfileControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  test "theme update persists selected theme" do
    user = users(:one)
    sign_in_as(user)

    patch my_settings_appearance_theme_path, params: { user: { theme: "nord" } }

    assert_response :redirect
    assert_redirected_to my_settings_appearance_path
    assert_equal "nord", user.reload.theme
  end

  test "region update normalizes blank country code to nil" do
    user = users(:one)
    user.update!(country_code: "US")
    sign_in_as(user)

    patch my_settings_profile_region_path, params: { user: { country_code: "" } }

    assert_response :redirect
    assert_nil user.reload.country_code
  end

  test "display name update persists override" do
    user = users(:one)
    user.update!(slack_username: "slack_name")
    sign_in_as(user)

    patch my_settings_profile_display_name_path, params: { user: { display_name_override: "Custom Name" } }

    assert_response :redirect
    assert_redirected_to my_settings_profile_path
    assert_equal "Custom Name", user.reload.display_name_override
    assert_equal "Custom Name", user.display_name
  end

  test "display name update clears blank override" do
    user = users(:one)
    user.update!(display_name_override: "Custom Name", slack_username: "slack_name")
    sign_in_as(user)

    patch my_settings_profile_display_name_path, params: { user: { display_name_override: " " } }

    assert_response :redirect
    assert_nil user.reload.display_name_override
    assert_equal "slack_name", user.display_name
  end

  test "display name update with invalid display name returns unprocessable entity" do
    user = users(:one)
    sign_in_as(user)

    patch my_settings_profile_display_name_path, params: {
      user: { display_name_override: "a" * (User::DISPLAY_NAME_MAX_LENGTH + 1) }
    }

    assert_response :unprocessable_entity
    assert_inertia_component "Users/Settings/Profile"
  end

  test "username update with invalid username returns unprocessable entity" do
    user = users(:one)
    user.update!(username: "good_name")
    sign_in_as(user)

    patch my_settings_profile_username_path, params: { user: { username: "bad username!" } }

    assert_response :unprocessable_entity
    assert_inertia_component "Users/Settings/Profile"
  end
end
