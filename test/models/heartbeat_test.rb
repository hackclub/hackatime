require "test_helper"

class HeartbeatTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "soft delete hides record from default scope and restore brings it back" do
    user = User.create!(timezone: "UTC")
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

  test "daily streak cache is separated for browser-filtered leaderboard streaks" do
    user = User.create!(timezone: "UTC", username: "hb_streak_cache")
    create_heartbeat_sequence(user: user, started_at: 1.day.ago.beginning_of_day + 9.hours, editor: "firefox")

    assert_equal 1, Heartbeat.daily_streaks_for_users([ user.id ])[user.id]
    assert_equal 0, Heartbeat.daily_streaks_for_users([ user.id ], exclude_browser_time: true)[user.id]
  end

  private

  def create_heartbeat_sequence(user:, started_at:, editor:, count: 9)
    count.times do |offset|
      user.heartbeats.create!(
        entity: "src/#{editor}.rb",
        type: "file",
        category: "coding",
        editor: editor,
        time: (started_at + (offset * 2).minutes).to_f,
        project: "heartbeat-test",
        source_type: :test_entry
      )
    end
  end
end
