require "test_helper"
require "uri"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActiveRecord::FixtureSet.reset_cache
  end

  # -- HCA: hca_new stores continue in session --

  test "hca_new stores continue path for oauth authorize" do
    continue_query = {
      client_id: "Ck47_6hihaBqZO7z3CLmJlCB-0NzHtZHGeDBwG4CqRs",
      redirect_uri: "https://game.hackclub.com/hackatime/callback",
      response_type: "code",
      scope: "profile read",
      state: "a254695483383bd70ee41424b75d638a869e5d6769e11b50"
    }
    continue_path = "/oauth/authorize?#{Rack::Utils.build_query(continue_query)}"

    get hca_auth_path(continue: continue_path)

    assert_equal continue_path, session.dig(:return_data, "url")
    assert_response :redirect
    assert_redirected_to %r{/oauth/authorize}
  end

  test "hca_new rejects external continue URL" do
    get hca_auth_path(continue: "https://evil.example.com/phish")

    assert_nil session.dig(:return_data, "url")
    assert_response :redirect
    assert_redirected_to %r{/oauth/authorize}
  end

  test "hca_new rejects javascript continue URL" do
    get hca_auth_path(continue: "javascript:alert(1)")

    assert_nil session.dig(:return_data, "url")
    assert_response :redirect
    assert_redirected_to %r{/oauth/authorize}
  end

  test "hca_new rejects protocol-relative continue URL" do
    get hca_auth_path(continue: "//evil.example.com/phish")

    assert_nil session.dig(:return_data, "url")
    assert_response :redirect
    assert_redirected_to %r{/oauth/authorize}
  end

  # -- Signin: preserves continue param --

  test "signin renders with continue param in inertia props" do
    oauth_path = "/oauth/authorize?client_id=test&response_type=code"

    get signin_path(continue: oauth_path)

    assert_response :success
    assert_inertia_component "Auth/SignIn"
    assert_inertia_prop "continue_param", oauth_path
  end

  test "signin renders without continue param when not provided" do
    get signin_path

    assert_response :success
    assert_inertia_component "Auth/SignIn"
    assert_inertia_prop "continue_param", nil
  end

  # -- Email auth: persists continue into sign-in token --

  test "email auth stores continue param in sign-in token" do
    user = User.create!
    email = "continue-test-#{SecureRandom.hex(4)}@example.com"
    user.email_addresses.create!(email: email)

    oauth_path = "/oauth/authorize?client_id=test&response_type=code"

    post email_auth_path, params: { email: email, continue: oauth_path }

    assert_response :redirect

    token = SignInToken.last
    assert_not_nil token
    assert_equal oauth_path, token.continue_param
  end

  test "email token redirects to continue param after sign in" do
    user = User.create!
    oauth_path = "/oauth/authorize?client_id=test&response_type=code"
    sign_in_token = user.sign_in_tokens.create!(
      auth_type: :email,
      continue_param: oauth_path
    )

    get auth_token_path(token: sign_in_token.token)

    assert_response :redirect
    assert_redirected_to oauth_path
    assert_equal user.id, session[:user_id]
  end

  test "email token falls back to root when no continue param" do
    user = User.create!
    sign_in_token = user.sign_in_tokens.create!(auth_type: :email)

    get auth_token_path(token: sign_in_token.token)

    assert_response :redirect
    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end

  test "email token rejects external continue URL" do
    user = User.create!
    sign_in_token = user.sign_in_tokens.create!(
      auth_type: :email,
      continue_param: "https://evil.example.com/phish"
    )

    get auth_token_path(token: sign_in_token.token)

    assert_response :redirect
    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end

  test "email token rejects protocol-relative continue URL" do
    user = User.create!
    sign_in_token = user.sign_in_tokens.create!(
      auth_type: :email,
      continue_param: "//evil.example.com/phish"
    )

    get auth_token_path(token: sign_in_token.token)

    assert_response :redirect
    assert_redirected_to root_path
  end

  test "slack_new stores oauth nonce and embeds it in state" do
    get slack_auth_path(close_window: true, continue: "/projects")

    assert_response :redirect
    assert_not_nil session[:slack_oauth_state_nonce]

    redirect_query = Rack::Utils.parse_nested_query(URI.parse(response.redirect_url).query)
    state = JSON.parse(redirect_query["state"])

    assert_equal session[:slack_oauth_state_nonce], state["token"]
    assert_equal true, state["close_window"]
    assert_equal "/projects", state["continue"]
  end

  test "slack_create rejects oauth callback with mismatched state nonce" do
    get slack_auth_path
    expected_nonce = session[:slack_oauth_state_nonce]

    get "/auth/slack/callback", params: { code: "oauth-code", state: { token: "wrong-#{expected_nonce}" }.to_json }

    assert_response :redirect
    assert_redirected_to root_path
    assert_nil session[:slack_oauth_state_nonce]
  end

  test "github_new stores oauth nonce and passes it in redirect state" do
    user = User.create!
    sign_in_as(user)

    get github_auth_path

    assert_response :redirect
    assert_not_nil session[:github_oauth_state_nonce]

    redirect_query = Rack::Utils.parse_nested_query(URI.parse(response.redirect_url).query)
    assert_equal session[:github_oauth_state_nonce], redirect_query["state"]
  end

  test "github_create rejects oauth callback with mismatched state nonce" do
    user = User.create!
    sign_in_as(user)

    get github_auth_path
    expected_nonce = session[:github_oauth_state_nonce]

    get "/auth/github/callback", params: { code: "oauth-code", state: "wrong-#{expected_nonce}" }

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert_nil session[:github_oauth_state_nonce]
  end

  test "expired token redirects to root with alert" do
    user = User.create!
    sign_in_token = user.sign_in_tokens.create!(
      auth_type: :email,
      continue_param: "/oauth/authorize?client_id=test",
      expires_at: 1.hour.ago
    )

    get auth_token_path(token: sign_in_token.token)

    assert_response :redirect
    assert_redirected_to root_path
    assert_nil session[:user_id]
  end

  test "used token redirects to root with alert" do
    user = User.create!
    sign_in_token = user.sign_in_tokens.create!(
      auth_type: :email,
      continue_param: "/oauth/authorize?client_id=test",
      used_at: 1.minute.ago
    )

    get auth_token_path(token: sign_in_token.token)

    assert_response :redirect
    assert_redirected_to root_path
    assert_nil session[:user_id]
  end

  test "github_unlink clears github fields for signed-in user" do
    user = User.create!(github_uid: "12345", github_username: "octocat", github_access_token: "secret-token")
    sign_in_as(user)

    delete github_unlink_path

    assert_response :redirect
    assert_redirected_to my_settings_path

    user.reload
    assert_nil user.github_uid
    assert_nil user.github_username
    assert_nil user.github_access_token
  end

  test "add_email creates email verification request" do
    user = User.create!
    sign_in_as(user)

    assert_difference -> { user.reload.email_verification_requests.count }, 1 do
      post add_email_auth_path, params: { email: "new-address@example.com" }
    end

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert_equal "new-address@example.com", user.reload.email_verification_requests.last.email
  end

  test "unlink_email removes secondary signing-in email" do
    user = User.create!
    removable = user.email_addresses.create!(email: "remove-me@example.com", source: :signing_in)
    user.email_addresses.create!(email: "keep-me@example.com", source: :signing_in)
    sign_in_as(user)

    assert_difference -> { user.reload.email_addresses.count }, -1 do
      delete unlink_email_auth_path, params: { email: removable.email }
    end

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert_not user.reload.email_addresses.exists?(email: removable.email)
  end

  test "auth token verifies email verification request token" do
    user = User.create!
    verification_request = user.email_verification_requests.create!(email: "verify-me@example.com")

    assert_difference -> { user.reload.email_addresses.count }, 1 do
      get auth_token_path(token: verification_request.token)
    end

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert verification_request.reload.deleted_at.present?
    assert user.reload.email_addresses.exists?(email: "verify-me@example.com")
  end

  test "impersonate and stop impersonating swaps active user session" do
    admin = User.create!(admin_level: :admin)
    target = User.create!
    sign_in_as(admin)

    get impersonate_user_path(target.id)

    assert_response :redirect
    assert_redirected_to root_path
    assert_equal target.id, session[:user_id]
    assert_equal admin.id, session[:impersonater_user_id]

    get stop_impersonating_path

    assert_response :redirect
    assert_redirected_to root_path
    assert_equal admin.id, session[:user_id]
    assert_nil session[:impersonater_user_id]
  end
end
