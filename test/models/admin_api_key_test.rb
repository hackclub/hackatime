require "test_helper"

class AdminApiKeyTest < ActiveSupport::TestCase
  test "stores a fixed-length preview of the token" do
    admin = User.create!(timezone: "UTC", admin_level: :admin)
    key = admin.admin_api_keys.create!(name: "CLI")
    raw_token = key.token

    assert_equal 13, AdminApiKey::TOKEN_PREVIEW_LENGTH
    assert_equal raw_token.first(13), key.reload.token_preview
  end
end
