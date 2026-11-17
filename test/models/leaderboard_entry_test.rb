require "test_helper"

class LeaderboardEntryTest < ActiveSupport::TestCase
  test "credited_ai_seconds counts 90% for the first three hours" do
    assert_equal 0, LeaderboardEntry.credited_ai_seconds(0)
    assert_in_delta 0.9.hours, LeaderboardEntry.credited_ai_seconds(1.hour.to_i)
    assert_in_delta 2.7.hours, LeaderboardEntry.credited_ai_seconds(3.hours.to_i)
  end

  test "credited_ai_seconds deflates each later hour more and never passes 4.5 hours" do
    credited = (3..24).map { |hours| LeaderboardEntry.credited_ai_seconds(hours.hours.to_i) }
    gains = credited.each_cons(2).map { |a, b| b - a }

    assert gains.all?(&:positive?)
    assert gains.each_cons(2).all? { |a, b| b < a }
    assert_in_delta 0.9 * Math.exp(-1.5), LeaderboardEntry.credited_ai_seconds(6.hours.to_i + 1) - LeaderboardEntry.credited_ai_seconds(6.hours.to_i), 0.001
    assert_operator LeaderboardEntry.credited_ai_seconds(8.hours.to_i), :<, 4.5.hours
    assert_operator LeaderboardEntry.credited_ai_seconds(1.week.to_i), :<=, 4.5.hours
  end
end
