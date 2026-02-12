require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActiveRecord::FixtureSet.reset_cache
  end

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

  # -- Minimal login: preserves continue param --

  test "minimal_login renders with continue param available for auth links" do
    oauth_path = "/oauth/authorize?client_id=test&response_type=code"

    get minimal_login_path(continue: oauth_path)

    assert_response :success
    assert_select "a[href*='continue']", minimum: 1
    assert_select "input[name='continue'][value=?]", oauth_path
  end

  test "minimal_login renders without continue param when not provided" do
    get minimal_login_path

    assert_response :success
    assert_select "input[name='continue']", count: 0
  end

  # -- Email auth: persists continue into sign-in token --

  test "email auth stores continue param in sign-in token" do
    user = User.create!
    user.email_addresses.create!(email: "test@example.com")

    oauth_path = "/oauth/authorize?client_id=test&response_type=code"

    # LoopsMailer forces SMTP delivery even in test; temporarily override
    original_delivery_method = LoopsMailer.delivery_method
    begin
      LoopsMailer.delivery_method = :test
      post email_auth_path, params: { email: "test@example.com", continue: oauth_path }
    ensure
      LoopsMailer.delivery_method = original_delivery_method
    end

    assert_response :redirect

    token = SignInToken.last
    assert_not_nil token
    assert_equal oauth_path, token.continue_param
  end

  test "email token redirects user with heartbeats to continue param after sign in" do
    user = User.create!
    user.heartbeats.create!(time: Time.current.to_f, source_type: :test_entry)
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

  test "email token redirects user without heartbeats to wakatime setup with continue stored in session" do
    user = User.create!
    oauth_path = "/oauth/authorize?client_id=test&response_type=code"
    sign_in_token = user.sign_in_tokens.create!(
      auth_type: :email,
      continue_param: oauth_path
    )

    get auth_token_path(token: sign_in_token.token)

    assert_response :redirect
    assert_redirected_to my_wakatime_setup_path
    assert_equal user.id, session[:user_id]
    assert_equal oauth_path, session.dig(:return_data, "url")
  end

  test "email token falls back to root when no continue param for user with heartbeats" do
    user = User.create!
    user.heartbeats.create!(time: Time.current.to_f, source_type: :test_entry)
    sign_in_token = user.sign_in_tokens.create!(auth_type: :email)

    get auth_token_path(token: sign_in_token.token)

    assert_response :redirect
    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end

  test "email token sends user without heartbeats to wakatime setup when no continue param" do
    user = User.create!
    sign_in_token = user.sign_in_tokens.create!(auth_type: :email)

    get auth_token_path(token: sign_in_token.token)

    assert_response :redirect
    assert_redirected_to my_wakatime_setup_path
    assert_equal user.id, session[:user_id]
  end

  test "email token rejects external continue URL for user with heartbeats" do
    user = User.create!
    user.heartbeats.create!(time: Time.current.to_f, source_type: :test_entry)
    sign_in_token = user.sign_in_tokens.create!(
      auth_type: :email,
      continue_param: "https://evil.example.com/phish"
    )

    get auth_token_path(token: sign_in_token.token)

    assert_response :redirect
    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end

  test "email token rejects protocol-relative continue URL for user with heartbeats" do
    user = User.create!
    user.heartbeats.create!(time: Time.current.to_f, source_type: :test_entry)
    sign_in_token = user.sign_in_tokens.create!(
      auth_type: :email,
      continue_param: "//evil.example.com/phish"
    )

    get auth_token_path(token: sign_in_token.token)

    assert_response :redirect
    assert_redirected_to root_path
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

  # -- HCA callback: new user without heartbeats --

  test "hca_create redirects user without heartbeats to wakatime setup" do
    user = User.create!
    User.define_singleton_method(:from_hca_token) { |_code, _uri| user }
    get "/auth/hca/callback", params: { code: "fake_code" }

    assert_response :redirect
    assert_redirected_to my_wakatime_setup_path
    assert_equal user.id, session[:user_id]
  ensure
    User.singleton_class.remove_method(:from_hca_token)
  end

  test "hca_create stores continue in session for user without heartbeats" do
    user = User.create!
    oauth_path = "/oauth/authorize?client_id=test&response_type=code"

    User.define_singleton_method(:from_hca_token) { |_code, _uri| user }
    get "/auth/hca/callback", params: { code: "fake_code", continue: oauth_path }

    assert_response :redirect
    assert_redirected_to my_wakatime_setup_path
    assert_equal oauth_path, session.dig(:return_data, "url")
  ensure
    User.singleton_class.remove_method(:from_hca_token)
  end

  test "hca_create does not overwrite return_data with nil for unsafe continue URL" do
    user = User.create!

    # Simulate hca_new having set a valid return URL
    get hca_auth_path(continue: "/oauth/authorize?client_id=test")

    User.define_singleton_method(:from_hca_token) { |_code, _uri| user }
    get "/auth/hca/callback", params: { code: "fake_code", continue: "https://evil.example.com" }

    assert_response :redirect
    assert_redirected_to my_wakatime_setup_path
    assert_equal "/oauth/authorize?client_id=test", session.dig(:return_data, "url")
  ensure
    User.singleton_class.remove_method(:from_hca_token)
  end

  # -- Slack callback: new user without heartbeats --

  test "slack_create redirects user without heartbeats to wakatime setup" do
    user = User.create!
    state = { "continue" => "/oauth/authorize?client_id=test" }.to_json

    User.define_singleton_method(:from_slack_token) { |_code, _uri| user }
    get "/auth/slack/callback", params: { code: "fake_code", state: state }

    assert_response :redirect
    assert_redirected_to my_wakatime_setup_path
    assert_equal user.id, session[:user_id]
    assert_equal "/oauth/authorize?client_id=test", session.dig(:return_data, "url")
  ensure
    User.singleton_class.remove_method(:from_slack_token)
  end

  test "slack_create redirects user with heartbeats to continue URL" do
    user = User.create!
    user.heartbeats.create!(time: Time.current.to_f, source_type: :test_entry)
    oauth_path = "/oauth/authorize?client_id=test&response_type=code"
    state = { "continue" => oauth_path }.to_json

    User.define_singleton_method(:from_slack_token) { |_code, _uri| user }
    get "/auth/slack/callback", params: { code: "fake_code", state: state }

    assert_response :redirect
    assert_redirected_to oauth_path
  ensure
    User.singleton_class.remove_method(:from_slack_token)
  end
end
