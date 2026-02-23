require "test_helper"

class HeartbeatImportSourceTest < ActiveSupport::TestCase
  test "validates one source per user" do
    user = User.create!(timezone: "UTC")

    HeartbeatImportSource.create!(
      user: user,
      provider: :wakatime_compatible,
      endpoint_url: "https://wakatime.com/api/v1",
      encrypted_api_key: "abc123"
    )

    duplicate = HeartbeatImportSource.new(
      user: user,
      provider: :wakatime_compatible,
      endpoint_url: "https://wakapi.dev/api/compat/wakatime/v1",
      encrypted_api_key: "xyz789"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "requires https endpoint outside development" do
    source = HeartbeatImportSource.new(
      user: User.create!(timezone: "UTC"),
      provider: :wakatime_compatible,
      endpoint_url: "http://example.com/api/v1",
      encrypted_api_key: "abc123"
    )

    assert_not source.valid?
    assert_includes source.errors[:endpoint_url], "must use https"
  end

  test "validates backfill date range order" do
    source = HeartbeatImportSource.new(
      user: User.create!(timezone: "UTC"),
      provider: :wakatime_compatible,
      endpoint_url: "https://example.com/api/v1",
      encrypted_api_key: "abc123",
      initial_backfill_start_date: Date.new(2026, 2, 10),
      initial_backfill_end_date: Date.new(2026, 2, 1)
    )

    assert_not source.valid?
    assert_includes source.errors[:initial_backfill_end_date], "must be on or after the start date"
  end
end
