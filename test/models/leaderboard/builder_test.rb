require "test_helper"

class Leaderboard::BuilderTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "force: true rebuilds a finished board (overwrites entries and bumps timestamp)" do
    user = create_user(username: "force_user", github_uid: "GH_FORCE")
    board = Leaderboard.create!(
      start_date: Date.current,
      period_type: :daily,
      finished_generating_at: 1.hour.ago
    )
    # Pre-existing stale entry from a previous build.
    LeaderboardEntry.create!(leaderboard: board, user: user, total_seconds: 999)
    original_finished_at = board.finished_generating_at

    create_heartbeat_pair(user: user, started_at: 2.hours.ago)

    Leaderboard::Builder.new(period: :daily, date: Date.current).call(force: true)

    board.reload
    assert_operator board.finished_generating_at, :>, original_finished_at
    # Stale 999 row got overwritten with the real ~120s aggregation.
    assert_equal 120, board.entries.find_by!(user_id: user.id).total_seconds
  end

  test "filters users below MIN_TOTAL_SECONDS (60s)" do
    short_user = create_user(username: "short_user", github_uid: "GH_SHORT")
    long_user = create_user(username: "long_user", github_uid: "GH_LONG")

    # 30s pair — below the 60s floor.
    create_heartbeat_pair(user: short_user, started_at: 1.hour.ago, gap_seconds: 30)
    # 120s pair — above the floor.
    create_heartbeat_pair(user: long_user, started_at: 1.hour.ago, gap_seconds: 120)

    Leaderboard::Builder.new(period: :daily, date: Date.current).call(force: true)

    board = Leaderboard.find_by!(start_date: Date.current, period_type: :daily)
    assert_equal [ long_user.id ], board.entries.pluck(:user_id)
  end

  test "empty data path prunes all stale entries" do
    user = create_user(username: "stale_user", github_uid: "GH_STALE")
    board = Leaderboard.create!(start_date: Date.current, period_type: :daily)
    LeaderboardEntry.create!(leaderboard: board, user: user, total_seconds: 500)
    # No heartbeats produced — but a stale entry exists. The builder should
    # delete it on rebuild.

    Leaderboard::Builder.new(period: :daily, date: Date.current).call

    assert_equal 0, board.reload.entries.count
  end

  test "delegates two-phase streak optimization to Heartbeat.daily_streaks_for_users" do
    # The two-phase optimization queries Heartbeat.daily_streaks_for_users
    # twice when any user's streak hits the SHORT_STREAK_MAX (6) ceiling.
    # We pin the contract by stubbing the underlying call and asserting
    # both calls occur with the expected windows.
    user = create_user(username: "streaky", github_uid: "GH_STREAKY")
    create_heartbeat_pair(user: user, started_at: 2.hours.ago)

    short_window_seen = false
    full_window_seen = false

    Heartbeat.singleton_class.alias_method :__orig_daily_streaks, :daily_streaks_for_users
    Heartbeat.define_singleton_method(:daily_streaks_for_users) do |ids, start_date:, **rest|
      window_days = ((Time.current - start_date) / 1.day).round
      if window_days <= 8
        short_window_seen = true
        # Force every queried user to look maxed-out so the second phase fires.
        ids.to_h { |id| [ id, Leaderboard::Builder::SHORT_STREAK_MAX ] }
      else
        full_window_seen = true
        ids.to_h { |id| [ id, 12 ] }
      end
    end

    begin
      Leaderboard::Builder.new(period: :daily, date: Date.current).call(force: true)
    ensure
      Heartbeat.singleton_class.alias_method :daily_streaks_for_users, :__orig_daily_streaks
      Heartbeat.singleton_class.remove_method :__orig_daily_streaks
    end

    assert short_window_seen, "expected short-window streak query to run"
    assert full_window_seen, "expected full-window streak query to run for maxed users"

    board = Leaderboard.find_by!(start_date: Date.current, period_type: :daily)
    assert_equal 12, board.entries.find_by!(user_id: user.id).streak_count
  end

  test "skips full-window streak query when no user maxes the short window" do
    user = create_user(username: "low_streak", github_uid: "GH_LOWS")
    create_heartbeat_pair(user: user, started_at: 2.hours.ago)

    full_window_called = false

    Heartbeat.singleton_class.alias_method :__orig_daily_streaks, :daily_streaks_for_users
    Heartbeat.define_singleton_method(:daily_streaks_for_users) do |ids, start_date:, **rest|
      window_days = ((Time.current - start_date) / 1.day).round
      if window_days <= 8
        ids.to_h { |id| [ id, 1 ] }
      else
        full_window_called = true
        ids.to_h { |id| [ id, 99 ] }
      end
    end

    begin
      Leaderboard::Builder.new(period: :daily, date: Date.current).call(force: true)
    ensure
      Heartbeat.singleton_class.alias_method :daily_streaks_for_users, :__orig_daily_streaks
      Heartbeat.singleton_class.remove_method :__orig_daily_streaks
    end

    refute full_window_called, "full-window query should be skipped when no user maxes short window"
    board = Leaderboard.find_by!(start_date: Date.current, period_type: :daily)
    assert_equal 1, board.entries.find_by!(user_id: user.id).streak_count
  end

  private

  def create_user(username:, github_uid:)
    User.create!(username: username, github_uid: github_uid, timezone: "UTC")
  end

  def create_heartbeat_pair(user:, started_at:, gap_seconds: 120)
    user.heartbeats.create!(
      entity: "src/file.rb", type: "file", category: "coding", editor: "vscode",
      time: started_at.to_f, project: "builder-test", source_type: :test_entry
    )
    user.heartbeats.create!(
      entity: "src/file.rb", type: "file", category: "coding", editor: "vscode",
      time: (started_at + gap_seconds).to_f, project: "builder-test", source_type: :test_entry
    )
  end
end
