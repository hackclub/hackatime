require "test_helper"

class EmailLoginTest < ActionDispatch::IntegrationTest
  test "full email sign-in flow creates token and signs user in" do
    email = "login-flow-#{SecureRandom.hex(4)}@example.com"
    user = create(:user, :with_email, email: email)

    assert_difference -> { SignInToken.count }, 1 do
      post email_auth_path, params: { email: email }
    end

    assert_response :redirect

    token = SignInToken.last
    assert_equal user.id, token.user_id

    get auth_token_path(token: token.token)

    assert_response :redirect
    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end

  test "email sign-in is case-insensitive" do
    email = "case-test-#{SecureRandom.hex(4)}@example.com"
    user = create(:user, :with_email, email: email)

    post email_auth_path, params: { email: email.upcase }

    assert_response :redirect

    token = SignInToken.last
    assert_equal user.id, token.user_id
  end

  test "email sign-in with continue param preserves redirect" do
    email = "continue-#{SecureRandom.hex(4)}@example.com"
    user = create(:user, :with_email, email: email)
    continue_path = "/oauth/authorize?client_id=test&response_type=code"

    post email_auth_path, params: { email: email, continue: continue_path }

    token = SignInToken.last
    assert_equal continue_path, token.continue_param

    get auth_token_path(token: token.token)

    assert_response :redirect
    assert_redirected_to continue_path
    assert_equal user.id, session[:user_id]
  end

  test "email sign-in token can only be used once" do
    email = "once-#{SecureRandom.hex(4)}@example.com"
    user = create(:user, :with_email, email: email)

    post email_auth_path, params: { email: email }
    token = SignInToken.last

    get auth_token_path(token: token.token)
    assert_equal user.id, session[:user_id]

    delete signout_path
    assert_nil session[:user_id]

    get auth_token_path(token: token.token)
    assert_redirected_to root_path
    assert_nil session[:user_id]
  end

  test "invalid token shows error" do
    get auth_token_path(token: "completely-bogus-token")

    assert_redirected_to root_path
    assert_nil session[:user_id]
  end

  test "email verification flow adds email to user" do
    user = create(:user)
    sign_in_as(user)

    new_email = "verify-#{SecureRandom.hex(4)}@example.com"

    assert_difference -> { user.email_verification_requests.count }, 1 do
      post add_email_auth_path, params: { email: new_email }
    end

    assert_redirected_to my_settings_path

    verification_request = user.email_verification_requests.last
    assert_equal new_email, verification_request.email

    assert_difference -> { user.email_addresses.count }, 1 do
      get auth_token_path(token: verification_request.token)
    end

    assert user.reload.email_addresses.exists?(email: new_email)
  end

  test "sign out clears session" do
    user = create(:user)
    sign_in_as(user)

    assert_equal user.id, session[:user_id]

    delete signout_path

    assert_redirected_to root_path
    assert_nil session[:user_id]
  end

  test "sign out revokes copied cookies without signing out other sessions" do
    user = create(:user)
    sign_in_as(user)
    copied_cookie = cookies["_hackatime_session"]

    other_device = open_session
    other_token = create(:sign_in_token, user: user, auth_type: :email)
    other_device.get auth_token_path(token: other_token.token)

    replay = open_session
    replay.cookies["_hackatime_session"] = copied_cookie
    replay.patch my_settings_profile_display_name_path, params: { user: { display_name_override: "Before logout" } }
    assert_equal "Before logout", user.reload.display_name

    delete signout_path

    replay.cookies["_hackatime_session"] = copied_cookie
    replay.patch my_settings_profile_display_name_path, params: { user: { display_name_override: "After logout" } }
    assert_equal "Before logout", user.reload.display_name
    replay.assert_redirected_to root_path
    replay.cookies["_hackatime_session"] = copied_cookie
    replay.get my_settings_path
    replay.assert_redirected_to root_path

    other_device.patch my_settings_profile_display_name_path, params: { user: { display_name_override: "Other device" } }
    assert_equal "Other device", user.reload.display_name
  end

  test "log out all devices revokes only the signed-in account including copied cookies" do
    user = create(:user, display_name_override: "Unchanged")
    other_user = create(:user)
    sign_in_as(user)
    copied_cookie = cookies["_hackatime_session"]
    devices = [ user, other_user ].map do |account|
      device = open_session
      token = create(:sign_in_token, user: account, auth_type: :email)
      device.get auth_token_path(token: token.token)
      device
    end

    post my_settings_logout_all_devices_path, params: { user_id: other_user.id }
    assert_redirected_to signin_path
    get my_settings_path
    assert_redirected_to root_path

    devices.first.get my_settings_path
    devices.first.assert_redirected_to root_path
    devices.last.patch my_settings_profile_display_name_path, params: { user: { display_name_override: "Still signed in" } }
    assert_equal "Still signed in", other_user.reload.display_name

    cookies["_hackatime_session"] = copied_cookie
    patch my_settings_profile_display_name_path, params: { user: { display_name_override: "Stolen cookie" } }
    assert_redirected_to root_path
    assert_equal "Unchanged", user.reload.display_name

    sign_in_as(user)
    patch my_settings_profile_display_name_path, params: { user: { display_name_override: "Signed in again" } }
    assert_equal "Signed in again", user.reload.display_name
  end

  test "log out all devices requires authentication" do
    user = create(:user)
    device = open_session
    token = create(:sign_in_token, user: user, auth_type: :email)
    device.get auth_token_path(token: token.token)

    post my_settings_logout_all_devices_path, params: { user_id: user.id }
    assert_redirected_to root_path

    device.patch my_settings_profile_display_name_path, params: { user: { display_name_override: "Still signed in" } }
    assert_equal "Still signed in", user.reload.display_name
  end

  test "log out all devices revokes impersonation sessions for either identity" do
    admin = create(:user, :admin)
    target = create(:user)

    [ admin, target ].each do |account|
      impersonating_device = open_session
      token = create(:sign_in_token, user: admin, auth_type: :email)
      impersonating_device.get auth_token_path(token: token.token)
      impersonating_device.get impersonate_user_path(target.id)
      impersonating_device.assert_redirected_to root_path

      sign_in_as(account)
      post my_settings_logout_all_devices_path
      assert_redirected_to signin_path

      impersonating_device.get my_settings_path
      impersonating_device.assert_redirected_to root_path
      impersonating_device.get stop_impersonating_path
      impersonating_device.get my_settings_path
      impersonating_device.assert_redirected_to root_path
    end
  end

  test "legacy cookie-only sessions cannot authenticate" do
    user = create(:user, display_name_override: "Original name")
    get signin_path
    legacy_jar = ActionDispatch::Cookies::CookieJar.build(request, {})
    legacy_jar.encrypted["_hackatime_session"] = {
      value: { "session_id" => SecureRandom.hex(16), "user_id" => user.id },
      expires: 14.days.from_now
    }
    assert_equal user.id, legacy_jar.encrypted["_hackatime_session"]["user_id"]

    cookies["_hackatime_session"] = legacy_jar["_hackatime_session"]
    patch my_settings_profile_display_name_path, params: { user: { display_name_override: "Legacy cookie" } }

    assert_redirected_to root_path
    assert_equal "Original name", user.reload.display_name
  end

  test "new user gets subscribed to weekly summary by default" do
    user = create(:user)
    assert user.subscribed?("weekly_summary"), "New users should be subscribed to weekly_summary"
  end
end
