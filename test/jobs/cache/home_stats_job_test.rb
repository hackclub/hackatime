require "test_helper"

class Cache::HomeStatsJobTest < ActiveSupport::TestCase
  test "calculates tracked users and seconds from grouped heartbeat durations" do
    travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
      first = User.create!(timezone: "UTC")
      second = User.create!(timezone: "UTC")
      single = User.create!(timezone: "UTC")
      base = Time.current

      create_heartbeat(user: first, time: base.to_f, project: "one", category: "coding", source_type: :test_entry)
      create_heartbeat(user: first, time: (base + 60.seconds).to_f, project: "one", category: "coding", source_type: :test_entry)
      create_heartbeat(user: second, time: base.to_f, project: "two", category: "coding", source_type: :test_entry)
      create_heartbeat(user: second, time: (base + 5.minutes).to_f, project: "two", category: "coding", source_type: :test_entry)
      create_heartbeat(user: single, time: base.to_f, project: "single", category: "coding", source_type: :test_entry)

      assert_equal(
        { users_tracked: 2, seconds_tracked: 180 },
        Cache::HomeStatsJob.new.send(:calculate)
      )
    end
  end
end
