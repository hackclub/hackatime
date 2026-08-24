require "test_helper"

class Api::V1::My::HeartbeatsControllerTest < ActionDispatch::IntegrationTest
  test "index accepts OAuth access token with read scope" do
    user = create(:user)
    heartbeat = create(:heartbeat,
      user:,
      source_type: :direct_entry,
      time: Time.current.to_f,
      project: "oauth-project"
    )
    access_token = create_oauth_access_token(user, scopes: "profile read")

    get "/api/v1/my/heartbeats", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :success
    assert_equal [ heartbeat.id ], response.parsed_body.fetch("heartbeats").pluck("id")
  end

  test "index rejects OAuth access token without read scope" do
    user = create(:user)
    access_token = create_oauth_access_token(user, scopes: "profile")

    get "/api/v1/my/heartbeats", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :unauthorized
  end

  test "index continues to accept API keys" do
    user = create(:user)
    api_key = create(:api_key, user: user, name: "test")

    get "/api/v1/my/heartbeats", headers: { "Authorization" => "Bearer #{api_key.token}" }

    assert_response :success
  end

  test "index continues to accept API keys with Basic authentication" do
    user = create(:user)
    api_key = create(:api_key, user: user, name: "test")

    get "/api/v1/my/heartbeats", headers: { "Authorization" => "Basic #{Base64.strict_encode64(api_key.token)}" }

    assert_response :success
  end

  test "index rejects API keys belonging to restricted users" do
    user = create(:user, trust_level: :red)
    api_key = create(:api_key, user: user, name: "test")

    get "/api/v1/my/heartbeats", headers: { "Authorization" => "Bearer #{api_key.token}" }

    assert_response :unauthorized
  end

  test "index rejects non-canonical Basic credentials" do
    user = create(:user)
    api_key = create(:api_key, user: user, name: "test")
    encoded_token = Base64.strict_encode64(api_key.token)

    get "/api/v1/my/heartbeats", headers: { "Authorization" => "Basic #{encoded_token}!" }

    assert_response :unauthorized
  end

  test "index rejects Basic credentials containing invalid UTF-8" do
    user = create(:user)
    api_key = create(:api_key, user: user, name: "test")
    encoded_token = Base64.strict_encode64("#{api_key.token}\xFF".b)

    get "/api/v1/my/heartbeats", headers: { "Authorization" => "Basic #{encoded_token}" }

    assert_response :unauthorized
  end

  private

  def create_oauth_access_token(user, scopes:)
    application = create(:oauth_application, owner: user,
      name: "Test App",
      redirect_uri: "https://example.com/callback",
      scopes: scopes,
      confidential: true
    )

    create(:oauth_access_token,
      application: application,
      resource_owner_id: user.id,
      scopes: scopes,
      expires_in: 16.years
    )
  end
end
