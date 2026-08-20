require "test_helper"

class AdminApiKeyTest < ActiveSupport::TestCase
  test "uses a fast blind index for high-entropy tokens" do
    options = AdminApiKey.blind_indexes.fetch(:token)

    assert_equal :pbkdf2_sha256, options[:algorithm]
    assert_equal({ iterations: 1 }, options[:cost])
  end

  test "stores a fixed-length preview of the token" do
    admin = User.create!(timezone: "UTC", admin_level: :admin)
    key = admin.admin_api_keys.create!(name: "CLI")
    raw_token = key.token

    assert_equal 13, AdminApiKey::TOKEN_PREVIEW_LENGTH
    assert_equal raw_token.first(13), key.reload.token_preview
  end

  test "finds a key by its virtual token without storing plaintext" do
    admin = User.create!(timezone: "UTC", admin_level: :admin)
    key = admin.admin_api_keys.create!(name: "CLI")
    raw_token = key.token

    key.reload

    assert_nil key.token
    assert_equal key, AdminApiKey.find_by!(token: raw_token)
  end
end
