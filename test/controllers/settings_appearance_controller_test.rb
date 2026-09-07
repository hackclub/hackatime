require "test_helper"

class SettingsAppearanceControllerTest < ActionDispatch::IntegrationTest
  test "show provides theme options" do
    user = create(:user)
    sign_in_as(user)

    get my_settings_appearance_path

    assert_response :success
    assert_inertia_component "Users/Settings/Appearance"
    assert_equal [ "themes" ], inertia.props.fetch("options").keys
    assert_equal User.theme_options.as_json, inertia.props.dig("options", "themes")
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
