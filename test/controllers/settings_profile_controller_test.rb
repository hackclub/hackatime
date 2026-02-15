require "test_helper"

class SettingsProfileControllerTest < ActionDispatch::IntegrationTest
  test "profile update persists selected theme" do
    user = User.create!
    sign_in_as(user)

    patch my_settings_profile_path, params: { user: { theme: "nord" } }

    assert_response :redirect
    assert_redirected_to my_settings_profile_path
    assert_equal "nord", user.reload.theme
  end

  private

  def sign_in_as(user)
    token = user.sign_in_tokens.create!(auth_type: :email)
    get auth_token_path(token: token.token)
    assert_equal user.id, session[:user_id]
  end
end
