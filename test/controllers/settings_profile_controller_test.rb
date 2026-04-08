require "test_helper"

class SettingsProfileControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

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

  test "profile page exposes stable settings props as once props" do
    user = users(:one)
    sign_in_as(user)

    get my_settings_profile_path

    assert_response :success
    assert_inertia_component "Users/Settings/Profile"

    page = inertia_page
    assert_equal "section_paths", page.dig("onceProps", "section_paths", "prop")
    assert_equal "page_title", page.dig("onceProps", "page_title", "prop")
    assert_equal "heading", page.dig("onceProps", "heading", "prop")
    assert_equal "subheading", page.dig("onceProps", "subheading", "prop")
    assert_equal "options.countries", page.dig("onceProps", "options.countries", "prop")
    assert_equal "options.timezones", page.dig("onceProps", "options.timezones", "prop")
    assert_equal "options.themes", page.dig("onceProps", "options.themes", "prop")
  end
end
