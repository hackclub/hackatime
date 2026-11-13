require "test_helper"
require "uri"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

class SessionsControllerTest < ActionDispatch::IntegrationTest
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

  # -- HCA: state nonce and callback failures --

  test "hca_new stores oauth nonce and passes it in redirect state" do
    get hca_auth_path

    assert_response :redirect
    assert_not_nil session[:hca_oauth_state_nonce]

    redirect_query = Rack::Utils.parse_nested_query(URI.parse(response.redirect_url).query)
    assert_equal session[:hca_oauth_state_nonce], redirect_query["state"]
  end

  test "hca_create signs in with the state from hca_new and the state is single use" do
    user = create(:user, hca_id: "hca-existing")
    stub_hca_identity(id: "hca-existing")
    get hca_auth_path(continue: "/projects")
    nonce = session[:hca_oauth_state_nonce]

    get "/auth/hca/callback", params: { code: "oauth-code", state: nonce }

    assert_redirected_to "/projects"
    assert_equal user.id, session[:user_id]
    assert_nil session[:hca_oauth_state_nonce]

    delete signout_path
    get "/auth/hca/callback", params: { code: "oauth-code", state: nonce }

    assert_redirected_to root_path
    assert_nil session[:user_id]
  end

  test "hca_create rejects oauth callback with missing or mismatched state nonce" do
    create(:user, hca_id: "hca-existing")
    stub_hca_identity(id: "hca-existing")

    get "/auth/hca/callback", params: { code: "oauth-code" }

    assert_redirected_to root_path
    assert_nil session[:user_id]

    get hca_auth_path
    expected_nonce = session[:hca_oauth_state_nonce]
    get "/auth/hca/callback", params: { code: "oauth-code", state: "wrong-#{expected_nonce}" }

    assert_redirected_to root_path
    assert_nil session[:user_id]
    assert_equal expected_nonce, session[:hca_oauth_state_nonce]
    assert_not_requested :post, "#{HCAService.host}/oauth/token"
  end

  test "hca_create explains an identity conflict without signing in" do
    user = create(:user, hca_id: "hca-original")
    create(:email_address, user: user, email: "shared@example.com")
    stub_hca_identity(id: "hca-other", primary_email: "shared@example.com")
    get hca_auth_path

    get "/auth/hca/callback", params: { code: "oauth-code", state: session[:hca_oauth_state_nonce] }

    assert_redirected_to root_path
    assert_match(/different Hack Club account/, flash[:alert])
    assert_nil session[:user_id]
    assert_equal "hca-original", user.reload.hca_id
  end

  test "hca_create asks the user to retry when Hack Club Auth is unreachable" do
    stub_request(:post, "#{HCAService.host}/oauth/token").to_timeout

    assert_hca_callback_asks_to_retry
  end

  test "hca_create asks the user to retry when the token endpoint is rate limited" do
    stub_request(:post, "#{HCAService.host}/oauth/token")
      .to_return(status: 429, body: "Retry later\n", headers: { "Content-Type" => "text/plain" })

    assert_hca_callback_asks_to_retry
  end

  test "hca_create asks the user to retry when the identity cannot be read" do
    stub_request(:post, "#{HCAService.host}/oauth/token")
      .to_return(body: { access_token: "hca-token" }.to_json)
    stub_request(:get, "#{HCAService.host}/api/v1/me")
      .to_return(status: 503, body: "<html>Service Unavailable</html>")

    assert_hca_callback_asks_to_retry
  end

  # -- HCA: linking an identity to a signed-in account --

  test "hca_create links the identity to the signed-in account instead of signing in as its email match" do
    user = create(:user, :with_email, email: "legacy@example.com")
    email_match = create(:user, :with_email, email: "identity@example.com")
    sign_in_as(user)
    stub_hca_identity(id: "hca-linking", primary_email: "identity@example.com")

    get hca_auth_path(continue: "/my/settings")
    assert_equal "legacy@example.com", Rack::Utils.parse_query(URI.parse(response.location).query)["login_hint"]

    assert_no_difference "User.count" do
      get "/auth/hca/callback", params: { code: "oauth-code", state: session[:hca_oauth_state_nonce] }
    end

    assert_redirected_to "/my/settings"
    assert_match(/linked/i, flash[:notice])
    assert_equal user.id, session[:user_id]
    assert_equal "hca-linking", user.reload.hca_id
    assert_nil email_match.reload.hca_id
  end

  test "hca_create does not link an identity whose account is in use" do
    user = create(:user)
    holder = create(:user, hca_id: "hca-held")
    create(:heartbeat, user: holder)
    sign_in_as(user)
    stub_hca_identity(id: "hca-held")
    get hca_auth_path

    get "/auth/hca/callback", params: { code: "oauth-code", state: session[:hca_oauth_state_nonce] }

    assert_redirected_to root_path
    assert_match(/already has its own Hackatime account.*Sign out and sign in with Hack Club/, flash[:alert])
    assert_equal user.id, session[:user_id]
    assert_nil user.reload.hca_id
    assert_equal "hca-held", holder.reload.hca_id
  end

  test "an identity moved off an unused account takes its email and Slack sign-in with it" do
    user = create(:user)
    create(:user, :with_email, email: "moving@example.com", hca_id: "hca-moving", slack_uid: "U_MOVING")
    sign_in_as(user)
    stub_hca_identity(id: "hca-moving", slack_id: "U_MOVING", primary_email: "moving@example.com")
    get hca_auth_path
    get "/auth/hca/callback", params: { code: "oauth-code", state: session[:hca_oauth_state_nonce] }
    assert_equal "hca-moving", user.reload.hca_id
    reset!

    post email_auth_path, params: { email: "moving@example.com" }
    assert_equal user, SignInToken.last.user

    stub_slack_identity(id: "U_MOVING", email: "moving@example.com")
    get slack_auth_path
    get "/auth/slack/callback", params: { code: "oauth-code", state: { token: session[:slack_oauth_state_nonce] }.to_json }
    assert_equal user.id, session[:user_id]
  end

  test "hca_create does not link an identity while impersonating" do
    admin = create(:user, :admin, hca_id: "hca-admin")
    target = create(:user)
    sign_in_as(admin)
    get impersonate_user_path(target.id)
    stub_hca_identity(id: "hca-admin")
    get hca_auth_path

    get "/auth/hca/callback", params: { code: "oauth-code", state: session[:hca_oauth_state_nonce] }

    assert_redirected_to root_path
    assert_match(/impersonating/, flash[:alert])
    assert_equal target.id, session[:user_id]
    assert_nil target.reload.hca_id
    assert_equal "hca-admin", admin.reload.hca_id
  end

  # -- Signin: preserves continue param --

  test "signin renders with continue param in inertia props" do
    oauth_path = "/oauth/authorize?client_id=test&response_type=code"

    get signin_path(continue: oauth_path)

    assert_response :success
    assert_inertia_component "Auth/SignIn"
    assert_inertia_props continue_param: oauth_path
  end

  test "signin renders without continue param when not provided" do
    get signin_path

    assert_response :success
    assert_inertia_component "Auth/SignIn"
    assert_inertia_props continue_param: nil
  end

  # -- Email auth: persists continue into sign-in token --

  test "email auth stores continue param in sign-in token" do
    email = "continue-test-#{SecureRandom.hex(4)}@example.com"
    user = create(:user, :with_email, email: email)

    oauth_path = "/oauth/authorize?client_id=test&response_type=code"

    post email_auth_path, params: { email: email, continue: oauth_path }

    assert_response :redirect

    token = SignInToken.last
    assert_not_nil token
    assert_equal oauth_path, token.continue_param
  end

  test "email auth does not create an account for an unknown email and answers the same way" do
    assert_no_difference [ "User.count", "EmailAddress.count", "SignInToken.count" ] do
      post email_auth_path, params: { email: "nobody-#{SecureRandom.hex(4)}@example.com" }
    end
    unknown_response = [ response.location, flash[:notice] ]

    email = "known-#{SecureRandom.hex(4)}@example.com"
    create(:user, :with_email, email: email)
    assert_difference "SignInToken.count", 1 do
      post email_auth_path, params: { email: email }
    end

    assert_equal unknown_response, [ response.location, flash[:notice] ]
  end

  test "email auth does not send a sign-in link for a deleted account" do
    email = "deleted-#{SecureRandom.hex(4)}@example.com"
    AnonymizeUserService.call(create(:user, :with_email, email: email))

    assert_no_difference "SignInToken.count" do
      post email_auth_path, params: { email: email }
    end

    assert_nil session[:dev_magic_link]
  end

  test "email auth sends a sign-in link for an email with no source" do
    email = "no-source-#{SecureRandom.hex(4)}@example.com"
    create(:email_address, user: create(:user), email: email, source: nil)

    assert_difference "SignInToken.count", 1 do
      post email_auth_path, params: { email: email }
    end
  end

  test "email auth uses the public URL for the development sign-in link" do
    original_public_url = ENV["PUBLIC_URL"]
    ENV["PUBLIC_URL"] = "https://hackatime.example.test/"
    email = "public-url-test-#{SecureRandom.hex(4)}@example.com"
    user = create(:user, :with_email, email: email)
    host! "3000-orb-id.e2b.app"

    post email_auth_path, params: { email: email }

    token = SignInToken.last
    assert_equal "https://hackatime.example.test/auth/token/#{token.token}", session[:dev_magic_link]
  ensure
    ENV["PUBLIC_URL"] = original_public_url
  end

  test "email auth uses the request URL when the public URL is blank" do
    original_public_url = ENV["PUBLIC_URL"]
    ENV["PUBLIC_URL"] = ""
    email = "blank-public-url-test-#{SecureRandom.hex(4)}@example.com"
    user = create(:user, :with_email, email: email)
    host! "hackatime.local"

    post email_auth_path, params: { email: email }

    token = SignInToken.last
    assert_equal "http://hackatime.local/auth/token/#{token.token}", session[:dev_magic_link]
  ensure
    ENV["PUBLIC_URL"] = original_public_url
  end

  test "email token redirects to continue param after sign in" do
    user = create(:user)
    oauth_path = "/oauth/authorize?client_id=test&response_type=code"
    sign_in_token = create(:sign_in_token, user: user,
      auth_type: :email,
      continue_param: oauth_path
    )

    get auth_token_path(token: sign_in_token.token)

    assert_response :redirect
    assert_redirected_to oauth_path
    assert_equal user.id, session[:user_id]
  end

  test "email token falls back to root when no continue param" do
    user = create(:user)
    sign_in_token = create(:sign_in_token, user: user, auth_type: :email)

    get auth_token_path(token: sign_in_token.token)

    assert_response :redirect
    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end

  test "email token rejects external continue URL" do
    user = create(:user)
    sign_in_token = create(:sign_in_token, user: user,
      auth_type: :email,
      continue_param: "https://evil.example.com/phish"
    )

    get auth_token_path(token: sign_in_token.token)

    assert_response :redirect
    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end

  test "email token rejects protocol-relative continue URL" do
    user = create(:user)
    sign_in_token = create(:sign_in_token, user: user,
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
    assert_equal expected_nonce, session[:slack_oauth_state_nonce]
  end

  test "slack_create does not create an account for an unknown Slack user" do
    stub_slack_identity(id: "U_UNKNOWN", email: "unknown-slack@example.com")
    get slack_auth_path

    assert_no_difference [ "User.count", "EmailAddress.count" ] do
      get "/auth/slack/callback", params: { code: "oauth-code", state: { token: session[:slack_oauth_state_nonce] }.to_json }
    end

    assert_redirected_to root_path
    assert_match(/Sign in with Hack Club/, flash[:alert])
    assert_nil session[:user_id]
  end

  test "slack_create does not sign in to a deleted account" do
    user = create(:user, :with_email, email: "deleted-slack@example.com")
    AnonymizeUserService.call(user)
    stub_slack_identity(id: "U_RETURNING", email: "deleted-slack@example.com")
    get slack_auth_path

    get "/auth/slack/callback", params: { code: "oauth-code", state: { token: session[:slack_oauth_state_nonce] }.to_json }

    assert_redirected_to root_path
    assert_match(/Sign in with Hack Club/, flash[:alert])
    assert_nil session[:user_id]
    assert_nil user.reload.slack_uid
    assert user.email_addresses.first!.source_preserved_for_deletion?
  end

  test "slack_create still signs in a deleted account that came back through Hack Club Auth" do
    user = create(:user, :with_email, email: "returned-slack@example.com")
    AnonymizeUserService.call(user)
    user.update!(hca_id: "hca-returned", slack_uid: "U_RETURNED")
    stub_slack_identity(id: "U_RETURNED", email: "returned-slack@example.com")
    get slack_auth_path

    get "/auth/slack/callback", params: { code: "oauth-code", state: { token: session[:slack_oauth_state_nonce] }.to_json }

    assert_equal user.id, session[:user_id]
    assert user.email_addresses.first!.source_preserved_for_deletion?
  end

  test "slack_create still signs in an existing Slack account" do
    user = create(:user, slack_uid: "U_EXISTING")
    stub_slack_identity(id: "U_EXISTING", email: "existing-slack@example.com")
    get slack_auth_path

    assert_no_difference "User.count" do
      get "/auth/slack/callback", params: { code: "oauth-code", state: { token: session[:slack_oauth_state_nonce] }.to_json }
    end

    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
    assert_equal [ "existing-slack@example.com" ], user.email_addresses.pluck(:email)
  end

  test "github_new stores oauth nonce and passes it in redirect state" do
    user = create(:user)
    sign_in_as(user)

    get github_auth_path

    assert_response :redirect
    assert_not_nil session[:github_oauth_state_nonce]

    redirect_query = Rack::Utils.parse_nested_query(URI.parse(response.redirect_url).query)
    assert_equal session[:github_oauth_state_nonce], redirect_query["state"]
  end

  test "github_create rejects oauth callback with mismatched state nonce" do
    user = create(:user)
    sign_in_as(user)

    get github_auth_path
    expected_nonce = session[:github_oauth_state_nonce]

    get "/auth/github/callback", params: { code: "oauth-code", state: "wrong-#{expected_nonce}" }

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert_equal expected_nonce, session[:github_oauth_state_nonce]
    assert_nil user.reload.github_uid
  end

  test "stale and missing GitHub state do not invalidate the latest attempt and successful state is single use" do
    user = create(:user)
    sign_in_as(user)
    get github_auth_path
    old_nonce = session[:github_oauth_state_nonce]
    get github_auth_path
    latest_nonce = session[:github_oauth_state_nonce]
    assert_not_equal old_nonce, latest_nonce

    [ old_nonce, nil ].each do |state|
      get "/auth/github/callback", params: { code: "stale-code", state: state }

      assert_redirected_to my_settings_path
      assert_equal "This GitHub linking attempt is no longer valid. Please try connecting GitHub again.", flash[:alert]
      assert_equal latest_nonce, session[:github_oauth_state_nonce]
      assert_nil user.reload.github_uid
    end

    stub_request(:post, "https://github.com/login/oauth/access_token")
      .with(body: hash_including("code" => "latest-code"))
      .to_return(body: { access_token: "github-token" }.to_json)
    stub_request(:get, "https://api.github.com/user")
      .with(headers: { "Authorization" => "Bearer github-token" })
      .to_return(body: { id: 12345, login: "octocat" }.to_json)

    get "/auth/github/callback", params: { code: "latest-code", state: latest_nonce }

    assert_redirected_to my_settings_path
    assert_equal "Successfully linked GitHub account!", flash[:notice]
    assert_equal "12345", user.reload.github_uid
    assert_equal "octocat", user.github_username
    assert_equal "github-token", user.github_access_token
    assert_nil session[:github_oauth_state_nonce]

    get "/auth/github/callback", params: { code: "latest-code", state: latest_nonce }

    assert_redirected_to my_settings_path
    assert_equal "This GitHub linking attempt is no longer valid. Please try connecting GitHub again.", flash[:alert]
    assert_equal "12345", user.reload.github_uid
  end

  test "GitHub callback after another sign in safely requires a new linking attempt" do
    original_user = create(:user)
    sign_in_as(original_user)
    get github_auth_path
    nonce = session[:github_oauth_state_nonce]
    current_user = create(:user)
    sign_in_as(current_user)

    get "/auth/github/callback", params: { code: "old-code", state: nonce }

    assert_redirected_to my_settings_path
    assert_equal "This GitHub linking attempt is no longer valid. Please try connecting GitHub again.", flash[:alert]
    assert_equal current_user.id, session[:user_id]
    assert_nil original_user.reload.github_uid
    assert_nil current_user.reload.github_uid
  end

  test "GitHub access denied is a normal cancellation" do
    user = create(:user)
    sign_in_as(user)
    get github_auth_path

    get "/auth/github/callback", params: { error: "access_denied", state: session[:github_oauth_state_nonce] }

    assert_redirected_to my_settings_path
    assert_equal "Sign in cancelled", flash[:alert]
    assert_nil user.reload.github_uid
  end

  test "expired token redirects to root with alert" do
    user = create(:user)
    sign_in_token = create(:sign_in_token, user: user,
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
    user = create(:user)
    sign_in_token = create(:sign_in_token, user: user,
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
    user = create(:user, github_uid: "12345", github_username: "octocat", github_access_token: "secret-token")
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
    user = create(:user)
    sign_in_as(user)

    assert_difference -> { user.reload.email_verification_requests.count }, 1 do
      post add_email_auth_path, params: { email: "new-address@example.com" }
    end

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert_equal "new-address@example.com", user.reload.email_verification_requests.last.email
  end

  test "add_email succeeds again after a pending request was removed" do
    user = create(:user)
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
    user = create(:user)
    verification_request = create(:email_verification_request, user: user, email: "pending@example.com")
    sign_in_as(user)

    old_token = verification_request.token
    post resend_email_verification_auth_path, params: { email: verification_request.email }

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert_equal old_token, verification_request.reload.token
  end

  test "resend_email_verification refreshes token after cooldown" do
    user = create(:user)
    verification_request = create(:email_verification_request, user: user, email: "pending-ok@example.com")
    verification_request.update_columns(created_at: 11.minutes.ago, updated_at: 11.minutes.ago)
    sign_in_as(user)

    old_token = verification_request.token
    post resend_email_verification_auth_path, params: { email: verification_request.email }

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert_not_equal old_token, verification_request.reload.token
  end

  test "resend_email_verification revives an expired request" do
    user = create(:user)
    verification_request = create(:email_verification_request, user: user, email: "expired-resend@example.com")
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
    user = create(:user)
    removable = create(:email_address, user: user, email: "remove-me@example.com", source: :signing_in)
    create(:email_address, user: user, email: "keep-me@example.com", source: :signing_in)
    sign_in_as(user)

    assert_difference -> { user.reload.email_addresses.count }, -1 do
      delete unlink_email_auth_path, params: { email: removable.email }
    end

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert_not user.reload.email_addresses.exists?(email: removable.email)
  end

  test "unlink_email removes pending verification request when email is unverified" do
    user = create(:user)
    verification_request = create(:email_verification_request, user: user, email: "pending-remove@example.com")
    sign_in_as(user)

    delete unlink_email_auth_path, params: { email: verification_request.email }

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert verification_request.reload.deleted_at.present?
  end

  test "unlink_email removes expired pending verification request" do
    user = create(:user)
    verification_request = create(:email_verification_request, user: user, email: "expired-remove@example.com")
    verification_request.update_columns(expires_at: 1.minute.ago)
    sign_in_as(user)

    delete unlink_email_auth_path, params: { email: verification_request.email }

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert verification_request.reload.deleted_at.present?
  end

  test "auth token verifies email verification request token" do
    user = create(:user)
    verification_request = create(:email_verification_request, user: user, email: "verify-me@example.com")

    assert_difference -> { user.reload.email_addresses.count }, 1 do
      get auth_token_path(token: verification_request.token)
    end

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert verification_request.reload.deleted_at.present?
    assert user.reload.email_addresses.exists?(email: "verify-me@example.com")
  end

  test "impersonate and stop impersonating swaps active user session" do
    admin = create(:user, :admin)
    target = create(:user)
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

  def assert_hca_callback_asks_to_retry
    get hca_auth_path

    assert_no_difference "User.count" do
      get "/auth/hca/callback", params: { code: "oauth-code", state: session[:hca_oauth_state_nonce] }
    end

    assert_redirected_to root_path
    assert_match(/try again/i, flash[:alert])
    assert_nil session[:user_id]
  end

  def stub_slack_identity(id:, email:)
    stub_request(:post, "https://slack.com/api/oauth.v2.access")
      .to_return(body: { ok: true, authed_user: { id: id, access_token: "slack-token", scope: "users:read" } }.to_json)
    stub_request(:get, "https://slack.com/api/users.info?user=#{id}")
      .to_return(body: { ok: true, user: { id: id, tz: "Europe/London", profile: { email: email } } }.to_json)
  end

  def stub_hca_identity(identity)
    stub_request(:post, "#{HCAService.host}/oauth/token")
      .to_return(body: { access_token: "hca-token" }.to_json)
    stub_request(:get, "#{HCAService.host}/api/v1/me")
      .with(headers: { "Authorization" => "Bearer hca-token" })
      .to_return(body: { identity: identity, scopes: %w[email slack_id] }.to_json)
  end
end
