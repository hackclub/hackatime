require "test_helper"

class SettingsAppearanceControllerTest < ActionDispatch::IntegrationTest
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
    assert_equal "Settings updated successfully", flash[:notice]

    follow_redirect!(headers: { "X-Inertia" => "true" })

    assert_response :success
    assert_equal true, response.parsed_body["clearHistory"]
  end
end
