require "test_helper"

class HeartbeatImportSourceTest < ActiveSupport::TestCase
  test "validates one source per user" do
    user = User.create!(timezone: "UTC")

    HeartbeatImportSource.create!(
      user: user,
      provider: :wakatime_compatible,
      endpoint_url: "https://wakatime.com/api/v1",
      encrypted_api_key: "waka_00000000-0000-0000-0000-000000000001"
    )

    duplicate = HeartbeatImportSource.new(
      user: user,
      provider: :wakatime_compatible,
      endpoint_url: "https://wakapi.dev/api/compat/wakatime/v1",
      encrypted_api_key: "waka_00000000-0000-0000-0000-000000000002"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "requires https endpoint outside development" do
    source = HeartbeatImportSource.new(
      user: User.create!(timezone: "UTC"),
      provider: :wakatime_compatible,
      endpoint_url: "http://example.com/api/v1",
      encrypted_api_key: "waka_00000000-0000-0000-0000-000000000001"
    )

    assert_not source.valid?
    assert_includes source.errors[:endpoint_url], "must use https"
  end
end
