require "test_helper"

class SailorsLogLeaderboardTest < ActiveSupport::TestCase
  test "returns no stats for channels with no opted-in users" do
    original_duration_grouped = StatsClient.method(:duration_grouped)
    StatsClient.singleton_class.send(:define_method, :duration_grouped) do |**_args|
      raise "duration_grouped should not be called for empty channels"
    end

    begin
      assert_equal [], SailorsLogLeaderboard.send(:generate_leaderboard_stats, "C-empty")
    ensure
      StatsClient.singleton_class.send(:define_method, :duration_grouped, original_duration_grouped)
    end
  end
end
