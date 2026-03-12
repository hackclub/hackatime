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

    assert_response :success
    assert_equal true, response.parsed_body["success"]
    assert_equal email_address.email, response.parsed_body["owner_email"]
    assert_equal key.name, response.parsed_body["key_name"]

    key.reload
    assert_not_equal original_token, key.token
    assert_nil ApiKey.find_by(token: original_token)

    post "/api/internal/revoke", params: { token: original_token }, headers: auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal({ "success" => false }, response.parsed_body)
  end

  test "returns success false for valid regular UUID token that does not exist" do
    token = SecureRandom.uuid_v4

    post "/api/internal/revoke", params: { token: token }, headers: auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal({ "success" => false }, response.parsed_body)
  end

  test "returns success false for token that matches neither regex" do
    post "/api/internal/revoke", params: { token: "not-a-valid-token" }, headers: auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal({ "success" => false }, response.parsed_body)
  end

  test "revokes admin key" do
    user = User.create!(timezone: "UTC")
    email_address = user.email_addresses.create!(email: "admin@example.com", source: :signing_in)
    admin_key = user.admin_api_keys.create!(name: "Infra", token: "hka_#{SecureRandom.hex(32)}")

    post "/api/internal/revoke", params: { token: admin_key.token }, headers: auth_headers, as: :json

    assert_response :success
    assert_equal true, response.parsed_body["success"]

    admin_key.reload
    assert_equal email_address.email, response.parsed_body["owner_email"]
    assert_equal admin_key.name, response.parsed_body["key_name"]
    assert_not_nil admin_key.revoked_at
    assert_includes admin_key.name, "_revoked_"
  end

  private

  def auth_headers
    {
      "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(ENV.fetch("HKA_REVOCATION_KEY"))
    }
  end
end
