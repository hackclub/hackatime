require "test_helper"

class TimelineServiceTest < ActiveSupport::TestCase
  setup do
    @original_timeout = Heartbeat.heartbeat_timeout_duration
    Heartbeat.heartbeat_timeout_duration(1.minute)
  end

  teardown do
    Heartbeat.heartbeat_timeout_duration(@original_timeout)
  end

  test "timeline_data derives total coded time from preloaded heartbeats" do
    user = User.create!(timezone: "UTC")

    create_heartbeat(user, Time.utc(2026, 1, 14, 9, 0, 0))
    create_heartbeat(user, Time.utc(2026, 1, 14, 9, 0, 30))
    create_heartbeat(user, Time.utc(2026, 1, 14, 9, 2, 0))

    data = TimelineService.new(date: Date.new(2026, 1, 14), selected_user_ids: [ user.id ]).timeline_data.first

    assert_equal 90, data[:total_coded_time]
    assert_equal 1, data[:spans].size
    assert_equal 120.0, data[:spans].first[:duration]
  end

  test "timeline_data respects each users local day when deriving totals" do
    user = User.create!(timezone: "America/New_York")

    create_heartbeat(user, Time.utc(2026, 1, 14, 4, 59, 30))
    create_heartbeat(user, Time.utc(2026, 1, 14, 5, 0, 0))
    create_heartbeat(user, Time.utc(2026, 1, 14, 5, 0, 30))

    data = TimelineService.new(date: Date.new(2026, 1, 14), selected_user_ids: [ user.id ]).timeline_data.first

    assert_equal 30, data[:total_coded_time]
  end

  private

  def create_heartbeat(user, time)
    user.heartbeats.create!(
      category: "coding",
      project: "timeline-test",
      editor: "vscode",
      entity: "src/app.rb",
      time: time.to_f,
      source_type: :test_entry
    )
  end
end
