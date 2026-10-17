require "test_helper"

class SettingsProfileControllerTest < ActionDispatch::IntegrationTest
  test "show provides profile options and pins a legacy timezone" do
    travel_to Time.utc(2026, 1, 15) do
      user = create(:user)
      user.update_column(:timezone, "Eastern Time (US & Canada)")
      sign_in_as(user)

      get my_settings_profile_path

      assert_response :success
      assert_inertia_component "Users/Settings/Profile"

      options = inertia.props.fetch("options")
      countries = options.fetch("countries")
      timezones = options.fetch("timezones")

      assert_equal %w[countries timezones], options.keys
      assert_equal countries.sort_by { |country| country.fetch("label") }, countries
      assert_equal({ "label" => "Afghanistan", "value" => "AF" }, countries.first)
      assert_equal({
        "label" => "Eastern Time (US & Canada) (UTC-05:00)",
        "value" => "Eastern Time (US & Canada)"
      }, timezones.first)
    end
  end

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

    patch my_settings_profile_display_name_path, params: { user: { display_name_override: "Custom Name" } }

    assert_response :redirect
    assert_redirected_to my_settings_profile_path
    assert_equal "Custom Name", user.reload.display_name_override
    assert_equal "Custom Name", user.display_name
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
