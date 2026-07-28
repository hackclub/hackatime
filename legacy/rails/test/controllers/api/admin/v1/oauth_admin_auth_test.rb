# frozen_string_literal: true

require "test_helper"

class Api::Admin::V1::OauthAdminAuthTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(timezone: "UTC", admin_level: :admin, username: "oauth_admin_auth")
    @oauth = @admin.oauth_applications.create!(
      name: "Fraud Tool",
      redirect_uri: "https://example.com/callback",
      scopes: "profile admin",
      confidential: true,
      verified: true
    )
  end

  test "accepts oauth admin token" do
    get "/api/admin/v1/check", headers: bearer(oauth_token(@admin, "admin").token)
    assert_response :success
    b = response.parsed_body
    assert_equal true, b["valid"]
    assert_equal "oauth", b.dig("auth", "type")
    assert_equal @oauth.uid, b.dig("auth", "application", "uid")
    assert_includes b.dig("auth", "scopes"), "admin"
    assert_equal @admin.id, b.dig("creator", "id")
  end

  test "rejects oauth token without admin scope" do
    get "/api/admin/v1/check", headers: bearer(oauth_token(@admin, "profile").token)
    assert_response :unauthorized
  end

  test "rejects oauth admin token after demotion" do
    t = oauth_token(@admin, "admin")
    @admin.update!(admin_level: :default)
    get "/api/admin/v1/check", headers: bearer(t.token)
    assert_response :unauthorized
  end

  test "rejects oauth admin token after application is unverified" do
    t = oauth_token(@admin, "admin")
    @oauth.update!(verified: false)
    get "/api/admin/v1/check", headers: bearer(t.token)
    assert_response :unauthorized
  end

  test "rejects oauth admin token after admin scope is removed from application" do
    t = oauth_token(@admin, "admin")
    @oauth.update!(scopes: "profile")
    get "/api/admin/v1/check", headers: bearer(t.token)
    assert_response :unauthorized
  end

  test "rejects oauth admin token when application is no longer confidential" do
    t = oauth_token(@admin, "admin")
    @oauth.update_column(:confidential, false)
    get "/api/admin/v1/check", headers: bearer(t.token)
    assert_response :unauthorized
  end

  test "still accepts admin api keys" do
    key = @admin.admin_api_keys.create!(name: "legacy")
    get "/api/admin/v1/check", headers: bearer(key.token)
    assert_response :success
    b = response.parsed_body
    assert_equal "api_key", b.dig("auth", "type")
    assert_equal key.id, b.dig("api_key", "id")
  end

  test "viewer oauth token can access admin check" do
    v = User.create!(timezone: "UTC", admin_level: :viewer)
    get "/api/admin/v1/check", headers: bearer(oauth_token(v, "admin").token)
    assert_response :success
    assert_equal "viewer", response.parsed_body.dig("creator", "admin_level")
  end

  private

  def oauth_token(u, scopes)
    Doorkeeper::AccessToken.create!(
      application: @oauth, resource_owner_id: u.id, scopes: scopes, expires_in: 16.years
    )
  end

  def bearer(t) = { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(t) }
end
