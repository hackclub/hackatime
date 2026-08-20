require "test_helper"

class Admin::AdminApiKeysControllerTest < ActionDispatch::IntegrationTest
  test "ultraadmin can revoke another user's admin API key" do
    ultraadmin = User.create!(timezone: "UTC", admin_level: :ultraadmin)
    owner = User.create!(timezone: "UTC", admin_level: :admin)
    key = owner.admin_api_keys.create!(name: "Other user's key")

    sign_in_as(ultraadmin)
    delete admin_admin_api_key_path(key)

    assert_redirected_to admin_admin_api_keys_path
    assert_not key.reload.active?
  end

  test "superadmin cannot revoke another user's admin API key" do
    superadmin = User.create!(timezone: "UTC", admin_level: :superadmin)
    owner = User.create!(timezone: "UTC", admin_level: :admin)
    key = owner.admin_api_keys.create!(name: "Other user's key")

    sign_in_as(superadmin)
    delete admin_admin_api_key_path(key)

    assert_redirected_to admin_admin_api_keys_path
    assert_predicate key.reload, :active?
  end
end
