require "test_helper"

class SailorsLogLeaderboardTest < ActiveSupport::TestCase
  test "leaderboard stats rank today's coding time for the channel's users" do
    sailors_log = create(:sailors_log)
    SailorsLogNotificationPreference.create!(slack_uid: sailors_log.slack_uid, slack_channel_id: "C123", enabled: true)
    user = sailors_log.user
    start = Time.current.beginning_of_day + 1.hour
    [ 0, 60, 120 ].each do |offset|
      create(:heartbeat, user:, time: (start + offset).to_f, project: "harbor", language: "Ruby", source_type: :test_entry)
    end

    stats = Time.use_zone(user.timezone) { SailorsLogLeaderboard.generate_leaderboard_stats("C123") }

    assert_equal 1, stats.size
    assert_equal [ user.slack_uid, 120 ], stats.first.values_at(:slack_uid, :duration)
    assert_equal [ [ "harbor", 120, "Ruby" ] ], stats.first[:projects].map { |p| p.values_at(:name, :duration, :language) }
  end
end
