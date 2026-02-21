require "test_helper"

class HeartbeatTest < ActiveSupport::TestCase
  test "soft delete hides record from default scope and restore brings it back" do
    user = User.create!
    heartbeat = user.heartbeats.create!(
      entity: "src/main.rb",
      type: "file",
      category: "coding",
      time: Time.current.to_f,
      project: "heartbeat-test",
      source_type: :test_entry
    )

    assert_includes Heartbeat.all, heartbeat

    heartbeat.soft_delete

    assert_not_includes Heartbeat.all, heartbeat
    assert_includes Heartbeat.with_deleted, heartbeat

    heartbeat.restore

    assert_includes Heartbeat.all, heartbeat
  end
end
