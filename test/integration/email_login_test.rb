require "test_helper"

class EmailLoginTest < ActionDispatch::IntegrationTest
  test "email sign-in entry point moves the user to HCA without creating a token" do
    email = "login-flow-#{SecureRandom.hex(4)}@example.com"

    assert_no_difference -> { SignInToken.count } do
      post email_auth_path, params: { email: email }
    end

    assert_redirected_to signin_path(login_hint: email)
    assert_nil session[:user_id]
  end

  test "email sign-in passes a normalized email to HCA as a login hint" do
    post email_auth_path, params: { email: "  Legacy@Example.COM " }

    assert_redirected_to signin_path(login_hint: "legacy@example.com")
  end

  test "email sign-in preserves a safe continuation for the HCA flow" do
    continue_path = "/oauth/authorize?client_id=test&response_type=code"

    post email_auth_path, params: { email: "legacy@example.com", continue: continue_path }

    assert_redirected_to signin_path(login_hint: "legacy@example.com", continue: continue_path)
  end

  test "legacy email sign-in token cannot create a session" do
    user = User.create!(timezone: "UTC")
    email = "once-#{SecureRandom.hex(4)}@example.com"
    user.email_addresses.create!(email: email, source: :signing_in)

    token = user.sign_in_tokens.create!(auth_type: :email)

    get auth_token_path(token: token.token)
    assert_redirected_to root_path
    assert_nil session[:user_id]
    assert_nil token.reload.used_at
  end

  test "expired email token does not sign user in" do
    user = User.create!(timezone: "UTC")
    token = user.sign_in_tokens.create!(
      auth_type: :email,
      expires_at: 1.hour.ago
    )

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
    user = User.create!(timezone: "UTC")
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
    user = User.create!(timezone: "UTC")
    sign_in_as(user)

    assert_equal user.id, session[:user_id]

    delete signout_path

    assert_redirected_to root_path
    assert_nil session[:user_id]
  end

  test "new user gets subscribed to weekly summary by default" do
    user = User.create!(timezone: "UTC")
    assert user.subscribed?("weekly_summary"), "New users should be subscribed to weekly_summary"
  end
end
