require "test_helper"

class WakatimeMirrorTest < ActiveSupport::TestCase
  def create_direct_heartbeat(user, at_time)
    user.heartbeats.create!(
      entity: "src/file.rb",
      type: "file",
      category: "coding",
      time: at_time.to_f,
      project: "mirror-test",
      source_type: :direct_entry
    )
  end

  test "initializes cursor at current heartbeat tip on create" do
    user = User.create!(timezone: "UTC")
    first = create_direct_heartbeat(user, Time.current - 5.minutes)
    second = create_direct_heartbeat(user, Time.current - 1.minute)

    mirror = user.wakatime_mirrors.create!(
      endpoint_url: "https://wakatime.com/api/v1",
      encrypted_api_key: "mirror-key"
    )

    assert_equal second.id, mirror.last_synced_heartbeat_id
    assert_operator second.id, :>, first.id
  end

  test "rejects endpoints that point to hackatime host" do
    user = User.create!(timezone: "UTC")
    mirror = user.wakatime_mirrors.build(
      endpoint_url: "https://hackatime.hackclub.com/api/v1",
      encrypted_api_key: "mirror-key"
    )

    assert_not mirror.valid?
    assert_includes mirror.errors[:endpoint_url], "cannot target this Hackatime host"
  end

  test "rejects app host equivalent endpoints" do
    user = User.create!(timezone: "UTC")
    mirror = user.wakatime_mirrors.build(
      endpoint_url: "https://example.com/api/v1",
      encrypted_api_key: "mirror-key"
    )

    mirror.request_host = "example.com"

    assert_not mirror.valid?
    assert_includes mirror.errors[:endpoint_url], "cannot target this Hackatime host"
  end
end
