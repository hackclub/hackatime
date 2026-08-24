require "test_helper"

class AdminApiKeyTest < ActiveSupport::TestCase
  test "stores a fixed-length preview of the token" do
    admin = create(:user, :admin)
    key = create(:admin_api_key, user: admin, name: "CLI")
    raw_token = key.token

    assert_equal 13, AdminApiKey::TOKEN_PREVIEW_LENGTH
    assert_equal raw_token.first(13), key.reload.token_preview
  end
end
