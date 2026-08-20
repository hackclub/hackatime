require "test_helper"

class AdminApiKeyTest < ActiveSupport::TestCase
  test "persists a digest and preview instead of the raw token" do
    user = User.create!(timezone: "UTC", admin_level: :admin)
    key = user.admin_api_keys.create!(name: "Integration")
    raw_token = key.token

    persisted_key = AdminApiKey.find(key.id)

    assert_match(/\Ahka_[0-9a-f]{64}\z/, raw_token)
    assert_equal Digest::SHA256.hexdigest(raw_token), persisted_key.token_digest
    assert_equal raw_token.first(21), persisted_key.token_preview
    assert_nil persisted_key.token
    assert_not_includes AdminApiKey.column_names, "token"
  end

  test "finds only active keys by their raw token" do
    user = User.create!(timezone: "UTC", admin_level: :admin)
    key = user.admin_api_keys.create!(name: "Integration")
    raw_token = key.token

    assert_equal key, AdminApiKey.find_active_by_token(raw_token)
    assert_nil AdminApiKey.find_active_by_token("not-the-token")

    key.revoke!

    assert_nil AdminApiKey.find_active_by_token(raw_token)
  end
end
