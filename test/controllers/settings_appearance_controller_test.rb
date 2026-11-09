require "test_helper"

class SettingsAppearanceControllerTest < ActionDispatch::IntegrationTest
  test "show redirects guests to sign in with the original URL" do
    settings_path = my_settings_appearance_path(source: "profile")

    get settings_path

    assert_response :redirect
    assert_redirected_to signin_path(continue: settings_path)
  end

  test "show renders appearance settings for an authenticated user" do
    user = create(:user)
    sign_in_as(user)

    get my_settings_appearance_path

    assert_response :success
    assert_inertia_component "Users/Settings/Appearance"
    assert_equal user.theme, inertia.props.dig("user", "theme")
  end

  test "expired session mutation continues to the GET settings page" do
    user = create(:user)
    sign_in_as(user)
    reset!

    patch my_settings_appearance_theme_path, params: { user: { theme: "nord" } }

    assert_response :redirect
    assert_redirected_to signin_path(continue: my_settings_appearance_path)
  end

  test "theme update persists selected theme and clears Inertia history" do
    user = create(:user)
    sign_in_as(user)

    patch my_settings_appearance_theme_path,
      params: { user: { theme: "nord" } },
      headers: { "X-Inertia" => "true" }

    assert_response :see_other
    assert_redirected_to my_settings_appearance_path
    assert_equal "nord", user.reload.theme
    assert_equal "nord", cookies[:hackatime_theme]

    follow_redirect!(headers: { "X-Inertia" => "true" })

    assert_response :success
    assert_equal true, response.parsed_body["clearHistory"]
  end
end
