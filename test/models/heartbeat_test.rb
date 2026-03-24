require "test_helper"

class HeartbeatTest < ActiveSupport::TestCase
  test "lightweight delete removes record from queries" do
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

    heartbeat.delete

    # After lightweight delete, the row is invisible to subsequent queries
    assert_not_includes Heartbeat.where(user_id: user.id).to_a, heartbeat
  end
end
