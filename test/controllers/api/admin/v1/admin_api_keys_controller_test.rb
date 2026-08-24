require "test_helper"

class Api::Admin::V1::AdminApiKeysControllerTest < ActionDispatch::IntegrationTest
  test "ultraadmin can revoke another user's admin API key" do
    ultraadmin = create(:user, :ultraadmin)
    authentication_key = create(:admin_api_key, user: ultraadmin, name: "Authentication key")
    owner = create(:user, :admin)
    key = create(:admin_api_key, user: owner, name: "Other user's key")

    delete "/api/admin/v1/admin_api_keys/#{key.id}", headers: auth_headers(authentication_key)

    assert_response :success
    assert_not key.reload.active?
  end

  test "superadmin cannot revoke another user's admin API key" do
    superadmin = create(:user, :superadmin)
    authentication_key = create(:admin_api_key, user: superadmin, name: "Authentication key")
    owner = create(:user, :admin)
    key = create(:admin_api_key, user: owner, name: "Other user's key")

    delete "/api/admin/v1/admin_api_keys/#{key.id}", headers: auth_headers(authentication_key)

    assert_response :forbidden
    assert_predicate key.reload, :active?
  end

  private

  def auth_headers(key)
    { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(key.token) }
  end
end
