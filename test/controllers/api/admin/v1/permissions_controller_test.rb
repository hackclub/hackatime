require "test_helper"

class Api::Admin::V1::PermissionsControllerTest < ActionDispatch::IntegrationTest
  test "update admin level records PaperTrail whodunnit from admin API key user" do
    admin = create(:user, :superadmin)
    key = create(:admin_api_key, user: admin, name: "test")
    user = create(:user, username: "api_perms_target")

    assert_difference -> { PaperTrail::Version.where(item_type: "User", item_id: user.id).count }, 1 do
      patch "/api/admin/v1/permissions/#{user.id}", params: { admin_level: "admin" }, headers: auth_headers(key), as: :json
    end

    assert_response :success
    assert_equal "admin", user.reload.admin_level
    assert_equal admin.id.to_s, PaperTrail::Version.where(item_type: "User", item_id: user.id).last.whodunnit
  end

  private

  def auth_headers(key)
    { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(key.token) }
  end
end
