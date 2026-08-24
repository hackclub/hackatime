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

  test "new user gets subscribed to weekly summary by default" do
    user = create(:user)
    assert user.subscribed?("weekly_summary"), "New users should be subscribed to weekly_summary"
  end
end
