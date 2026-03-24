require "test_helper"

class HeartbeatTest < ActiveSupport::TestCase
  def setup
    Rails.cache.clear
  end

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

  test "create bumps the user's heartbeat cache version" do
    user = User.create!(timezone: "UTC")
    initial_version = HeartbeatCacheInvalidator.version_for(user)

    user.heartbeats.create!(
      entity: "src/cache_bump.rb",
      type: "file",
      category: "coding",
      time: Time.current.to_f,
      project: "heartbeat-cache",
      source_type: :test_entry
    )

    assert_equal initial_version + 1, HeartbeatCacheInvalidator.version_for(user)
  end
end
