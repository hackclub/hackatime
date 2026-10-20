require "test_helper"

class Admin::AdminApiKeysControllerTest < ActionDispatch::IntegrationTest
  test "lists recorded usage in the viewer's timezone and leaves unknown usage blank" do
    admin = create(:user, :admin, timezone: "America/New_York")
    used_key = create(:admin_api_key, user: admin, name: "Used key", last_used_at: Time.utc(2026, 10, 20, 15, 23, 17))
    unused_key = create(:admin_api_key, user: admin, name: "Unused key")

    sign_in_as(admin)
    get admin_admin_api_keys_path

    assert_response :success
    assert_inertia_component "Admin/AdminApiKeys/Index"
    keys = inertia.props["api_keys"].index_by { |key| key["id"] }
    assert_equal "Oct 20, 2026 at 11:23 AM EDT", keys.fetch(used_key.id)["last_used_at"]
    assert_nil keys.fetch(unused_key.id)["last_used_at"]
  end

  test "ultraadmin can revoke another user's admin API key" do
    ultraadmin = create(:user, :ultraadmin)
    owner = create(:user, :admin)
    key = create(:admin_api_key, user: owner, name: "Other user's key")

    sign_in_as(ultraadmin)
    delete admin_admin_api_key_path(key)

    assert_redirected_to admin_admin_api_keys_path
    assert_not key.reload.active?
  end

  test "superadmin cannot revoke another user's admin API key" do
    superadmin = create(:user, :superadmin)
    owner = create(:user, :admin)
    key = create(:admin_api_key, user: owner, name: "Other user's key")

    sign_in_as(superadmin)
    delete admin_admin_api_key_path(key)

    assert_redirected_to admin_admin_api_keys_path
    assert_predicate key.reload, :active?
  end
end
