require "test_helper"

class Admin::AdminApiKeysControllerTest < ActionDispatch::IntegrationTest
  test "shows a newly created raw token only once without persisting it" do
    admin = User.create!(timezone: "UTC", admin_level: :admin)
    sign_in_as(admin)

    post admin_admin_api_keys_path, params: { admin_api_key: { name: "New key" } }

    key = admin.admin_api_keys.find_by!(name: "New key")
    assert_redirected_to admin_admin_api_key_path(key)
    follow_redirect!
    raw_token = inertia_page.dig("props", "api_key", "token")
    assert_equal true, inertia_page.dig("props", "show_token")
    assert_match(/\Ahka_[0-9a-f]{64}\z/, raw_token)
    assert_equal Digest::SHA256.hexdigest(raw_token), key.reload.token_digest
    assert_nil key.token

    get admin_admin_api_key_path(key)

    assert_equal false, inertia_page.dig("props", "show_token")
    assert_nil inertia_page.dig("props", "api_key", "token")
  end

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
