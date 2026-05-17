require "test_helper"

class CleanupOldLeaderboardsJobTest < ActiveJob::TestCase
  test "deletes boards whose start_date is older than the retention window" do
    old = Leaderboard.create!(
      start_date: 5.days.ago.to_date,
      period_type: :daily,
      finished_generating_at: 5.days.ago
    )

    CleanupOldLeaderboardsJob.perform_now

    refute Leaderboard.exists?(old.id)
  end

  test "preserves today's board even if its created_at is older than retention" do
    # Boards are upserted by (start_date, period_type) — today's daily board's
    # row may have been created days ago, but the period itself is still active.
    # Reaping by created_at would delete a live board out from under the cron
    # job; this test pins the corrected behavior.
    today_board = Leaderboard.create!(
      start_date: Date.current,
      period_type: :daily,
      finished_generating_at: Time.current
    )
    today_board.update_columns(created_at: 30.days.ago)

    CleanupOldLeaderboardsJob.perform_now

    assert Leaderboard.exists?(today_board.id)
  end

  test "is a no-op when nothing is past retention" do
    Leaderboard.create!(
      start_date: Date.current,
      period_type: :daily,
      finished_generating_at: Time.current
    )

    assert_nothing_raised { CleanupOldLeaderboardsJob.perform_now }
    assert_equal 1, Leaderboard.count
  end
end
