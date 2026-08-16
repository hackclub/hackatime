require "test_helper"

class Api::V1::Authenticated::MeControllerTest < ActionDispatch::IntegrationTest
  CODING_DATA_PATHS = [
    "/api/v1/authenticated/hours",
    "/api/v1/authenticated/streak",
    "/api/v1/authenticated/projects",
    "/api/v1/authenticated/heartbeats/latest"
  ].freeze

  test "index explicitly requires the profile scope" do
    user = User.create!(timezone: "UTC")
    profile_token = create_oauth_access_token(user, scopes: "profile")
    read_token = create_oauth_access_token(user, scopes: "read")

    get "/api/v1/authenticated/me", headers: bearer_header(profile_token)
    assert_response :success

    get "/api/v1/authenticated/me", headers: bearer_header(read_token)
    assert_response :forbidden
    assert_includes response.headers["WWW-Authenticate"], 'error="insufficient_scope"'
  end

  test "coding data endpoints explicitly require the read scope" do
    user = User.create!(timezone: "UTC")
    profile_token = create_oauth_access_token(user, scopes: "profile")
    read_token = create_oauth_access_token(user, scopes: "read")

    CODING_DATA_PATHS.each do |path|
      get path, headers: bearer_header(profile_token)
      assert_response :forbidden, "expected profile-only token to be forbidden for #{path}"
      assert_includes response.headers["WWW-Authenticate"], 'error="insufficient_scope"'

      get path, headers: bearer_header(read_token)
      assert_response :success, "expected read-only token to succeed for #{path}"
    end
  end

  test "missing revoked and expired credentials remain unauthorized" do
    user = User.create!(timezone: "UTC")
    revoked_token = create_oauth_access_token(user, scopes: "profile")
    revoked_token.revoke
    expired_token = create_oauth_access_token(user, scopes: "profile", created_at: 2.hours.ago, expires_in: 1.hour)

    [ nil, revoked_token, expired_token ].each do |token|
      headers = token ? bearer_header(token) : {}
      get "/api/v1/authenticated/me", headers: headers
      assert_response :unauthorized
    end
  end

  test "protected resources accept only bearer authorization credentials" do
    user = User.create!(timezone: "UTC")
    access_token = create_oauth_access_token(user, scopes: "profile")

    get "/api/v1/authenticated/me", headers: bearer_header(access_token)
    assert_response :success

    get "/api/v1/authenticated/me", params: { access_token: access_token.token }
    assert_response :unauthorized

    get "/api/v1/authenticated/me", params: { bearer_token: access_token.token }
    assert_response :unauthorized

    get "/api/v1/authenticated/me", params: { access_token: access_token.token }, as: :json
    assert_response :unauthorized

    get "/api/v1/authenticated/me", params: { bearer_token: access_token.token }, as: :json
    assert_response :unauthorized
  end

  test "OAuth token and revocation endpoints continue to accept body credentials" do
    user = User.create!(timezone: "UTC")
    application = create_oauth_application(user, scopes: "profile")
    application_secret = application.plaintext_secret
    grant = Doorkeeper::AccessGrant.create!(
      application: application,
      resource_owner_id: user.id,
      expires_in: 10.minutes,
      redirect_uri: application.redirect_uri,
      scopes: "profile"
    )

    post "/oauth/token", params: {
      grant_type: "authorization_code",
      code: grant.token,
      client_id: application.uid,
      client_secret: application_secret,
      redirect_uri: application.redirect_uri
    }
    assert_response :success
    issued_token = response.parsed_body.fetch("access_token")

    post "/oauth/revoke", params: {
      token: issued_token,
      client_id: application.uid,
      client_secret: application_secret
    }
    assert_response :success
    assert Doorkeeper::AccessToken.by_token(issued_token).revoked?
  end

  test "index allows red users" do
    user = User.create!(timezone: "UTC", trust_level: :red)
    access_token = create_oauth_access_token(user)

    get "/api/v1/authenticated/me", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :success
  end

  test "index rejects pending deletion users" do
    user = User.create!(timezone: "UTC")
    DeletionRequest.create_for_user!(user)
    access_token = create_oauth_access_token(user)

    get "/api/v1/authenticated/me", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :unauthorized
  end

  private

  def bearer_header(access_token)
    { "Authorization" => "Bearer #{access_token.token}" }
  end

  def create_oauth_application(user, scopes:)
    user.oauth_applications.create!(
      name: "Test App",
      redirect_uri: "https://example.com/callback",
      scopes: scopes,
      confidential: true
    )
  end

  def create_oauth_access_token(user, scopes: "profile", **attributes)
    application = create_oauth_application(user, scopes: scopes)

    Doorkeeper::AccessToken.create!(
      application: application,
      resource_owner_id: user.id,
      scopes: scopes,
      expires_in: 16.years,
      **attributes
    )
  end
end
