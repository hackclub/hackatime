require "test_helper"

class Api::V1::Authenticated::MeControllerTest < ActionDispatch::IntegrationTest
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

  def create_oauth_access_token(user, scopes: "profile")
    application = user.oauth_applications.create!(
      name: "Test App",
      redirect_uri: "https://example.com/callback",
      scopes: scopes,
      confidential: true
    )

    Doorkeeper::AccessToken.create!(
      application: application,
      resource_owner_id: user.id,
      scopes: scopes,
      expires_in: 16.years
    )
  end
end
