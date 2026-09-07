require "test_helper"

class SettingsProfileControllerTest < ActionDispatch::IntegrationTest
  test "region update normalizes blank country code to nil" do
    user = create(:user)
    user.update!(country_code: "US")
    sign_in_as(user)

    patch my_settings_profile_region_path, params: { user: { country_code: "" } }

    assert_response :redirect
    assert_nil user.reload.country_code
  end

  test "display name update persists override" do
    user = create(:user)
    user.update!(slack_username: "slack_name")
    sign_in_as(user)
    return_path = "#{my_settings_profile_path}?section=display-name"

    patch my_settings_profile_display_name_path,
      params: { user: { display_name_override: "Custom Name" } },
      headers: { "HTTP_REFERER" => return_path }

    assert_response :redirect
    assert_redirected_to return_path
    assert_equal "Custom Name", user.reload.display_name_override
    assert_equal "Custom Name", user.display_name
    assert_equal "Settings updated successfully", flash[:notice]
  end

  test "display name update clears blank override" do
    user = create(:user)
    user.update!(display_name_override: "Custom Name", slack_username: "slack_name")
    sign_in_as(user)

    patch my_settings_profile_display_name_path, params: { user: { display_name_override: " " } }

    assert_response :redirect
    assert_nil user.reload.display_name_override
    assert_equal "slack_name", user.display_name
  end

  test "display name update with invalid display name returns unprocessable entity" do
    user = create(:user)
    sign_in_as(user)

    patch my_settings_profile_display_name_path, params: {
      user: { display_name_override: "a" * (User::DISPLAY_NAME_MAX_LENGTH + 1) }
    }

    assert_response :unprocessable_entity
    assert_inertia_component "Users/Settings/Profile"
    assert_predicate flash[:error], :present?
    assert_nil user.reload.display_name_override
  end

  test "username update with invalid username returns unprocessable entity" do
    user = create(:user)
    user.update!(username: "good_name")
    sign_in_as(user)

    patch my_settings_profile_username_path, params: { user: { username: "bad username!" } }

    assert_response :unprocessable_entity
    assert_inertia_component "Users/Settings/Profile"
  end
end
