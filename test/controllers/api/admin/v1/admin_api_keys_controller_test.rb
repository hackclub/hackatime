require "test_helper"

class Api::Admin::V1::AdminApiKeysControllerTest < ActionDispatch::IntegrationTest
  test "creates an admin API key without persisting its raw token" do
    admin = User.create!(timezone: "UTC", admin_level: :admin)
    authentication_key = admin.admin_api_keys.create!(name: "Authentication key")

    post "/api/admin/v1/admin_api_keys", params: { name: "New key" }, headers: auth_headers(authentication_key), as: :json

    assert_response :created
    raw_token = response.parsed_body.dig("admin_api_key", "token")
    persisted_key = AdminApiKey.find(response.parsed_body.dig("admin_api_key", "id"))
    assert_match(/\Ahka_[0-9a-f]{64}\z/, raw_token)
    assert_equal Digest::SHA256.hexdigest(raw_token), persisted_key.token_digest
    assert_equal raw_token.first(21), persisted_key.token_preview
    assert_nil persisted_key.token
  end

  test "ultraadmin can revoke another user's admin API key" do
    ultraadmin = User.create!(timezone: "UTC", admin_level: :ultraadmin)
    authentication_key = ultraadmin.admin_api_keys.create!(name: "Authentication key")
    owner = User.create!(timezone: "UTC", admin_level: :admin)
    key = owner.admin_api_keys.create!(name: "Other user's key")

    delete "/api/admin/v1/admin_api_keys/#{key.id}", headers: auth_headers(authentication_key)

    assert_response :success
    assert_not key.reload.active?
  end

  test "superadmin cannot revoke another user's admin API key" do
    superadmin = User.create!(timezone: "UTC", admin_level: :superadmin)
    authentication_key = superadmin.admin_api_keys.create!(name: "Authentication key")
    owner = User.create!(timezone: "UTC", admin_level: :admin)
    key = owner.admin_api_keys.create!(name: "Other user's key")

    delete "/api/admin/v1/admin_api_keys/#{key.id}", headers: auth_headers(authentication_key)

    assert_response :forbidden
    assert_predicate key.reload, :active?
  end

  private

  def auth_headers(key)
    { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(key.token) }
  end
end
