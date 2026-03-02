# frozen_string_literal: true

require "test_helper"
require "json"

class CustomDoorkeeperAuthorizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(timezone: "UTC")
    @oauth_app = @user.oauth_applications.create!(
      name: "Test App",
      redirect_uri: "https://example.com/callback",
      scopes: "profile",
      confidential: true
    )
  end

  test "new redirects unauthenticated user to sign in" do
    get "/oauth/authorize", params: authorization_params
    assert_response :redirect
    assert_match %r{signin}, response.location
  end

  test "new renders OAuthAuthorize/New for authorizable request" do
    sign_in_as(@user)
    # Delete any existing tokens so it doesn't skip authorization
    Doorkeeper::AccessToken.where(application: @oauth_app).delete_all

    get "/oauth/authorize", params: authorization_params
    assert_response :success

    page = inertia_page
    assert_equal "OAuthAuthorize/New", page["component"]
    assert_equal @oauth_app.name, page.dig("props", "client_name")
    assert page.dig("props", "scopes").is_a?(Array)
    assert page.dig("props", "form_data", "client_id").present?
  end

  test "new skips authorization when matching token exists" do
    sign_in_as(@user)
    Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "profile",
      expires_in: 16.years
    )

    get "/oauth/authorize", params: authorization_params
    # Should redirect to callback with auth code, not render the form
    assert_response :redirect
    assert_match %r{example\.com/callback}, response.location
  end

  test "new renders error for invalid client_id" do
    sign_in_as(@user)
    get "/oauth/authorize", params: {
      client_id: "invalid",
      redirect_uri: "https://example.com/callback",
      response_type: "code",
      scope: "profile"
    }

    page = inertia_page
    assert_equal "OAuthAuthorize/Error", page["component"]
    assert page.dig("props", "error_description").present?
  end

  test "show renders OAuthAuthorize/Show with code" do
    sign_in_as(@user)
    get "/oauth/authorize/native", params: { code: "test_code" }

    assert_response :success
    page = inertia_page
    assert_equal "OAuthAuthorize/Show", page["component"]
    assert_equal "test_code", page.dig("props", "code")
  end

  private

  def authorization_params
    {
      client_id: @oauth_app.uid,
      redirect_uri: "https://example.com/callback",
      response_type: "code",
      scope: "profile"
    }
  end
end
