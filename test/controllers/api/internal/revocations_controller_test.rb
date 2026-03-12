require "test_helper"

class Api::Internal::RevocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_revocation_key = ENV["HKA_REVOCATION_KEY"]
    ENV["HKA_REVOCATION_KEY"] = "test-revocation-key"
  end

  teardown do
    ENV["HKA_REVOCATION_KEY"] = @previous_revocation_key
  end

  test "revokes regular ApiKey by rolling token" do
    user = User.create!(timezone: "UTC")
    email_address = user.email_addresses.create!(email: "regular@example.com", source: :signing_in)
    original_token = SecureRandom.uuid_v4
    key = user.api_keys.create!(name: "Desktop", token: original_token)

    post "/api/internal/revoke", params: { token: original_token }, headers: auth_headers, as: :json

    assert_response :created
    assert_equal true, response.parsed_body["success"]
    assert_equal "complete", response.parsed_body["status"]
    assert_equal "Hackatime API Key", response.parsed_body["token_type"]
    assert_equal email_address.email, response.parsed_body["owner_email"]
    assert_equal key.name, response.parsed_body["key_name"]

    key.reload
    assert_not_equal original_token, key.token
    assert_nil ApiKey.find_by(token: original_token)

    post "/api/internal/revoke", params: { token: original_token }, headers: auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal false, response.parsed_body["success"]
    assert_equal "Token is invalid or already revoked", response.parsed_body["error"]
  end

  test "returns success false for valid regular UUID token that does not exist" do
    token = SecureRandom.uuid_v4

    post "/api/internal/revoke", params: { token: token }, headers: auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal false, response.parsed_body["success"]
    assert_equal "Token is invalid or already revoked", response.parsed_body["error"]
  end

  test "returns success false for token that matches neither regex" do
    post "/api/internal/revoke", params: { token: "not-a-valid-token" }, headers: auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal false, response.parsed_body["success"]
    assert_equal "Token doesn't match any supported type", response.parsed_body["error"]
  end

  test "revokes admin key" do
    user = User.create!(timezone: "UTC")
    email_address = user.email_addresses.create!(email: "admin@example.com", source: :signing_in)
    admin_key = user.admin_api_keys.create!(name: "Infra", token: "hka_#{SecureRandom.hex(32)}")

    post "/api/internal/revoke", params: { token: admin_key.token }, headers: auth_headers, as: :json

    assert_response :created
    assert_equal true, response.parsed_body["success"]
    assert_equal "complete", response.parsed_body["status"]
    assert_equal "Hackatime Admin API Key", response.parsed_body["token_type"]

    admin_key.reload
    assert_equal email_address.email, response.parsed_body["owner_email"]
    assert_equal "Infra", response.parsed_body["key_name"]
    assert_not_nil admin_key.revoked_at
    assert_includes admin_key.name, "_revoked_"
  end

  test "returns error for already-revoked admin key" do
    user = User.create!(timezone: "UTC")
    original_token = "hka_#{SecureRandom.hex(32)}"
    admin_key = user.admin_api_keys.create!(name: "Infra", token: original_token)
    admin_key.revoke!

    # Token format still matches ADMIN_KEY_REGEX, but AdminApiKey.active won't find it.
    post "/api/internal/revoke", params: { token: original_token }, headers: auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal false, response.parsed_body["success"]
    assert_equal "Token is invalid or already revoked", response.parsed_body["error"]
  end

  private

  def auth_headers
    {
      "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(ENV.fetch("HKA_REVOCATION_KEY"))
    }
  end
end
