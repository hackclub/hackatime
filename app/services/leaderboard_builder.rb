module LeaderboardBuilder
  module_function

  def build_for_users(users, date, scope, period)
    date = Date.current if date.blank?

    board = ::Leaderboard.new(
      start_date: date,
      period_type: period,
      finished_generating_at: Time.current
    )

    ids = users.pluck(:id)
    return board if ids.empty?

    users_map = users.index_by(&:id)

    range = LeaderboardDateRange.calculate(date, period)
    result = StatsClient.leaderboard_compute(
      user_ids: ids,
      start_time: range.first.to_f,
      end_time: range.last.to_f,
      min_seconds: 60,
      include_streaks: true,
      coding_only: true,
      exclude_trust_level_red: false,
      require_github_uid: true
    )

    entries = Array(result["entries"]).map do |row|
      user_id = row["user_id"]
      entry = LeaderboardEntry.new(
        leaderboard: board,
        user_id: user_id,
        total_seconds: row["total_seconds"],
        streak_count: row["streak_count"] || 0
      )

      entry.user = users_map[user_id]
      entry
    end.sort_by(&:total_seconds).reverse

    board.define_singleton_method(:entries) { entries }
    board.define_singleton_method(:scope_name) { scope }

    board
  end
end
