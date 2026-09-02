require "test_helper"

class SettingsEditorsControllerTest < ActionDispatch::IntegrationTest
  test "editor update persists settings and redirects directly to editors" do
    user = create(:user)
    sign_in_as(user)

    patch my_settings_editors_update_path,
      params: { user: { hackatime_extension_text_type: "clock_emoji" } },
      headers: { "HTTP_REFERER" => my_settings_profile_path }

    assert_response :redirect
    assert_redirected_to my_settings_editors_path
    assert_equal "clock_emoji", user.reload.hackatime_extension_text_type
    assert_equal "Settings updated successfully", flash[:notice]
  end
end
