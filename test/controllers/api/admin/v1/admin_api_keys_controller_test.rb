require "test_helper"

class Api::Admin::V1::AdminApiKeysControllerTest < ActionDispatch::IntegrationTest
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
