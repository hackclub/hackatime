require "test_helper"
require "uri"
require "webmock/minitest"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActiveRecord::FixtureSet.reset_cache
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:hca] = hca_auth_hash
  end

  teardown { OmniAuth.config.mock_auth[:hca] = nil }

  # -- HCA: request phase preserves a safe continuation --

  test "hca_new stores continue path for oauth authorize" do
    continue_query = {
      client_id: "Ck47_6hihaBqZO7z3CLmJlCB-0NzHtZHGeDBwG4CqRs",
      redirect_uri: "https://game.hackclub.com/hackatime/callback",
      response_type: "code",
      scope: "profile read",
      state: "a254695483383bd70ee41424b75d638a869e5d6769e11b50"
    }
    continue_path = "/oauth/authorize?#{Rack::Utils.build_query(continue_query)}"
    user = User.create!(hca_id: "ident!test-user")
    user.email_addresses.create!(email: "hca-test@example.com", source: :hca)

    post hca_auth_path(continue: continue_path)
    follow_redirect!

    assert_redirected_to continue_path
    assert_equal user.id, session[:user_id]
    assert_equal "hca", session[:auth_provider]
  end

  test "hca_new rejects external continue URL" do
    user = User.create!(hca_id: "ident!test-user")
    user.email_addresses.create!(email: "hca-test@example.com", source: :hca)

    post hca_auth_path(continue: "https://evil.example.com/phish")
    follow_redirect!

    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end

  test "hca_new rejects javascript continue URL" do
    user = User.create!(hca_id: "ident!test-user")
    user.email_addresses.create!(email: "hca-test@example.com", source: :hca)

    post hca_auth_path(continue: "javascript:alert(1)")
    follow_redirect!

    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end

  test "hca_new rejects protocol-relative continue URL" do
    user = User.create!(hca_id: "ident!test-user")
    user.email_addresses.create!(email: "hca-test@example.com", source: :hca)

    post hca_auth_path(continue: "//evil.example.com/phish")
    follow_redirect!

    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end

  test "HCA callback rejects an unverified email" do
    OmniAuth.config.mock_auth[:hca] = hca_auth_hash(email_verified: false)

    post hca_auth_path
    follow_redirect!

    assert_redirected_to signin_path
    assert_nil session[:user_id]
    assert_nil session[:pending_hca]
  end

  test "HCA callback rejects a malformed subject" do
    OmniAuth.config.mock_auth[:hca] = hca_auth_hash(subject: "not-an-hca-subject")

    post hca_auth_path
    follow_redirect!

    assert_redirected_to signin_path
    assert_nil session[:user_id]
    assert_nil session[:pending_hca]
  end

  test "unknown HCA identity requires an explicit account choice" do
    OmniAuth.config.mock_auth[:hca] = hca_auth_hash(subject: "ident!new-user", email: "new-user@example.com")

    post hca_auth_path
    follow_redirect!

    assert_redirected_to signin_path
    assert_nil session[:user_id]
    assert_equal "ident!new-user", session.dig(:pending_hca, "subject")

    assert_difference -> { User.where(hca_id: "ident!new-user").count }, 1 do
      post hca_account_path
    end

    user = User.find_by!(hca_id: "ident!new-user")
    assert_redirected_to setup_path
    assert_equal user.id, session[:user_id]
    assert_equal "hca", session[:auth_provider]
    assert user.email_addresses.source_hca.exists?(email: "new-user@example.com")
  end

  test "HCA email recovery links the pending subject only in the initiating browser" do
    legacy_user = User.create!
    legacy_user.email_addresses.create!(email: "legacy-recovery@example.com", source: :signing_in)
    OmniAuth.config.mock_auth[:hca] = hca_auth_hash(subject: "ident!recovered", email: "new-hca@example.com")

    post hca_auth_path
    follow_redirect!
    post hca_recovery_path, params: { email: "legacy-recovery@example.com" }
    token = legacy_user.sign_in_tokens.hca_recovery.last

    assert_not_nil token
    assert_equal "ident!recovered", token.return_data["hca_subject"]

    other_browser = open_session
    other_browser.get auth_token_path(token: token.token)
    other_browser.assert_redirected_to signin_path
    assert_nil other_browser.session[:user_id]
    assert_nil token.reload.used_at

    get auth_token_path(token: token.token)

    assert_equal legacy_user.id, session[:user_id]
    assert_equal "ident!recovered", legacy_user.reload.hca_id
    assert token.reload.used_at.present?
  end

  test "HCA callback records and denies split legacy identities" do
    email_user = User.create!
    email_user.email_addresses.create!(email: "split-controller@example.com", source: :signing_in)
    slack_user = User.create!(slack_uid: "U_CONTROLLER_SPLIT")
    OmniAuth.config.mock_auth[:hca] = hca_auth_hash(
      subject: "ident!controller-split",
      email: "split-controller@example.com",
      slack_id: "U_CONTROLLER_SPLIT"
    )

    assert_difference -> { HCAIdentityConflict.count }, 1 do
      post hca_auth_path
      follow_redirect!
    end

    assert_redirected_to signin_path
    assert_nil session[:user_id]
    conflict = HCAIdentityConflict.last
    assert_equal "split_identity", conflict.reason
    assert_equal email_user.id, conflict.email_user_id
    assert_equal slack_user.id, conflict.slack_user_id
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

  # -- Legacy email entry points hand off to HCA --

  test "email auth redirects to HCA sign in with a login hint and safe continuation" do
    email = "continue-test-#{SecureRandom.hex(4)}@example.com"
    oauth_path = "/oauth/authorize?client_id=test&response_type=code"

    post email_auth_path, params: { email: email, continue: oauth_path }

    assert_response :redirect
    assert_redirected_to signin_path(login_hint: email, continue: oauth_path)
    assert_no_difference -> { SignInToken.count } do
      follow_redirect!
    end
    assert_inertia_prop "login_hint", email
    assert_inertia_prop "continue_param", oauth_path
  end

  test "email auth normalizes the HCA login hint" do
    post email_auth_path, params: { email: "  Person@Example.COM  " }

    assert_redirected_to signin_path(login_hint: "person@example.com")
  end

  test "email auth drops an unsafe continuation" do
    post email_auth_path, params: { email: "person@example.com", continue: "https://evil.example/phish" }

    assert_redirected_to signin_path(login_hint: "person@example.com")
  end

  test "legacy standalone sign-in tokens cannot create a session" do
    user = User.create!
    %i[email slack program_magic_link].each do |auth_type|
      sign_in_token = user.sign_in_tokens.create!(auth_type:)

      get auth_token_path(token: sign_in_token.token)

      assert_redirected_to root_path
      assert_nil session[:user_id]
      assert_nil sign_in_token.reload.used_at
    end
  end

  test "slack_new stores oauth nonce and embeds it in state" do
    user = User.create!(hca_id: "ident!test-user", slack_uid: "U_TEST")
    user.email_addresses.create!(email: "hca-test@example.com", source: :hca)
    post hca_auth_path
    follow_redirect!

    post slack_auth_path

    assert_response :redirect
    assert_not_nil session[:slack_oauth_state]

    redirect_query = Rack::Utils.parse_nested_query(URI.parse(response.redirect_url).query)
    state = JSON.parse(redirect_query["state"])

    assert_equal session[:slack_oauth_state], redirect_query["state"]
    assert_equal "integration", state["purpose"]
    assert_equal user.id, state["user_id"]
  end

  test "Slack cannot start a standalone login" do
    post slack_auth_path

    assert_redirected_to signin_path
    assert_nil session[:slack_oauth_state]
    assert_nil session[:user_id]
  end

  test "Slack integration requires a recent HCA authentication" do
    user = User.create!(hca_id: "ident!test-user", slack_uid: "U_TEST")
    user.email_addresses.create!(email: "hca-test@example.com", source: :hca)
    post hca_auth_path
    follow_redirect!

    travel 31.minutes do
      post slack_auth_path
    end

    assert_redirected_to signin_path
    assert_nil session[:slack_oauth_state]
    assert_equal user.id, session[:user_id]
  end

  test "Slack integration cannot switch the signed-in user" do
    user = User.create!(hca_id: "ident!test-user", slack_uid: "U_EXPECTED")
    user.email_addresses.create!(email: "hca-test@example.com", source: :hca)
    post hca_auth_path
    follow_redirect!
    post slack_auth_path
    state = session[:slack_oauth_state]
    stub_slack_identity("U_OTHER")

    get "/auth/slack/callback", params: { code: "oauth-code", state: state }

    assert_redirected_to signin_path
    assert_equal user.id, session[:user_id]
    assert_equal "U_EXPECTED", user.reload.slack_uid
    assert_nil user.slack_access_token
  end

  test "Slack integration can attach an unclaimed Slack identity to the signed-in HCA user" do
    user = User.create!(hca_id: "ident!test-user")
    user.email_addresses.create!(email: "hca-test@example.com", source: :hca)
    post hca_auth_path
    follow_redirect!
    post slack_auth_path
    state = session[:slack_oauth_state]
    stub_slack_identity("U_NEW_INTEGRATION")

    get "/auth/slack/callback", params: { code: "oauth-code", state: state }

    assert_redirected_to my_settings_path
    assert_equal user.id, session[:user_id]
    assert_equal "U_NEW_INTEGRATION", user.reload.slack_uid
    assert_equal "slack-access-token", user.slack_access_token
  end

  test "Slack recovery can link only after an unmatched HCA login" do
    legacy_user = User.create!(slack_uid: "U_RECOVERY")
    OmniAuth.config.mock_auth[:hca] = hca_auth_hash(subject: "ident!slack-recovered", email: "slack-recovered@example.com")
    post hca_auth_path
    follow_redirect!
    assert_equal "ident!slack-recovered", session.dig(:pending_hca, "subject")

    post slack_auth_path
    state = session[:slack_oauth_state]
    stub_slack_identity("U_RECOVERY")

    get "/auth/slack/callback", params: { code: "oauth-code", state: state }

    assert_redirected_to root_path
    assert_equal legacy_user.id, session[:user_id]
    assert_equal "ident!slack-recovered", legacy_user.reload.hca_id
    assert_equal "hca", session[:auth_provider]
  end

  test "Slack recovery rejects a Slack account that differs from the HCA claim" do
    legacy_user = User.create!(slack_uid: "U_RECOVERY_OTHER")
    OmniAuth.config.mock_auth[:hca] = hca_auth_hash(
      subject: "ident!slack-mismatch",
      email: "slack-mismatch@example.com",
      slack_id: "U_HCA_CLAIM"
    )
    post hca_auth_path
    follow_redirect!
    post slack_auth_path
    state = session[:slack_oauth_state]
    stub_slack_identity("U_RECOVERY_OTHER")

    assert_difference -> { HCAIdentityConflict.count }, 1 do
      get "/auth/slack/callback", params: { code: "oauth-code", state: state }
    end

    assert_redirected_to signin_path
    assert_nil session[:user_id]
    assert_nil legacy_user.reload.hca_id
    assert_equal "recovery_conflict", HCAIdentityConflict.last.reason
  end

  test "slack_create rejects oauth callback with mismatched state nonce" do
    user = User.create!(hca_id: "ident!test-user", slack_uid: "U_TEST")
    user.email_addresses.create!(email: "hca-test@example.com", source: :hca)
    post hca_auth_path
    follow_redirect!
    post slack_auth_path
    expected_state = session[:slack_oauth_state]

    get "/auth/slack/callback", params: { code: "oauth-code", state: "wrong-#{expected_state}" }

    assert_response :redirect
    assert_redirected_to root_path
    assert_nil session[:slack_oauth_state]
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

  test "add_email succeeds again after a pending request was removed" do
    user = User.create!
    sign_in_as(user)

    post add_email_auth_path, params: { email: "recycle@example.com" }
    delete unlink_email_auth_path, params: { email: "recycle@example.com" }

    # Re-adding the same email must not raise a unique-violation on the
    # soft-deleted request (partial index is scoped to deleted_at IS NULL).
    assert_difference -> { user.reload.email_verification_requests.where(deleted_at: nil).count }, 1 do
      post add_email_auth_path, params: { email: "recycle@example.com" }
    end

    assert_response :redirect
    assert_redirected_to my_settings_path
  end

  test "resend_email_verification enforces cooldown" do
    user = User.create!
    verification_request = user.email_verification_requests.create!(email: "pending@example.com")
    sign_in_as(user)

    old_token = verification_request.token
    post resend_email_verification_auth_path, params: { email: verification_request.email }

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert_equal old_token, verification_request.reload.token
  end

  test "resend_email_verification refreshes token after cooldown" do
    user = User.create!
    verification_request = user.email_verification_requests.create!(email: "pending-ok@example.com")
    verification_request.update_columns(created_at: 11.minutes.ago, updated_at: 11.minutes.ago)
    sign_in_as(user)

    old_token = verification_request.token
    post resend_email_verification_auth_path, params: { email: verification_request.email }

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert_not_equal old_token, verification_request.reload.token
  end

  test "resend_email_verification revives an expired request" do
    user = User.create!
    verification_request = user.email_verification_requests.create!(email: "expired-resend@example.com")
    verification_request.update_columns(
      created_at: 2.weeks.ago,
      updated_at: 2.weeks.ago,
      expires_at: 2.weeks.ago
    )
    sign_in_as(user)

    old_token = verification_request.token
    assert verification_request.expired?

    post resend_email_verification_auth_path, params: { email: verification_request.email }

    assert_response :redirect
    assert_redirected_to my_settings_path

    verification_request.reload
    assert_not_equal old_token, verification_request.token
    assert_not verification_request.expired?, "resending should extend the expiry"
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

  test "unlink_email removes pending verification request when email is unverified" do
    user = User.create!
    verification_request = user.email_verification_requests.create!(email: "pending-remove@example.com")
    sign_in_as(user)

    delete unlink_email_auth_path, params: { email: verification_request.email }

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert verification_request.reload.deleted_at.present?
  end

  test "unlink_email removes expired pending verification request" do
    user = User.create!
    verification_request = user.email_verification_requests.create!(email: "expired-remove@example.com")
    verification_request.update_columns(expires_at: 1.minute.ago)
    sign_in_as(user)

    delete unlink_email_auth_path, params: { email: verification_request.email }

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert verification_request.reload.deleted_at.present?
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

  private

  def stub_slack_identity(uid)
    stub_request(:post, "https://slack.com/api/oauth.v2.access")
      .to_return(body: {
        ok: true,
        authed_user: { id: uid, access_token: "slack-access-token", scope: "users.profile:read" }
      }.to_json)
    stub_request(:get, "https://slack.com/api/users.info?user=#{uid}")
      .to_return(body: { ok: true, user: { id: uid, profile: {} } }.to_json)
  end

  def hca_auth_hash(subject: "ident!test-user", email: "hca-test@example.com", slack_id: nil, email_verified: true)
    OmniAuth::AuthHash.new(
      provider: "hca",
      uid: subject,
      info: { email:, email_verified: },
      extra: {
        raw_info: {
          "sub" => subject,
          "email" => email,
          "email_verified" => email_verified,
          "slack_id" => slack_id
        }.compact
      }
    )
  end
end
