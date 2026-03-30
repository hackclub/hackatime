module LeaderboardBuilder
  module_function

  def build_for_users(users, date, scope, period)
    date = Date.current if date.blank?

    board = ::Leaderboard.new(
      start_date: date,
      period_type: period,
      finished_generating_at: Time.current
    )

    eligible_users = users.where.not(github_uid: nil)
    ids = eligible_users.pluck(:id)
    return board if ids.empty?

    range = LeaderboardDateRange.calculate(date, period)

    beats = Heartbeat.where(user_id: ids, time: range)
                    .leaderboard_eligible

    totals = beats.group(:user_id).duration_seconds
    totals = totals.filter { |_, seconds| seconds > 60 }
    users_map = eligible_users.where(id: totals.keys).index_by(&:id)

    streak_ids = totals.keys
    streaks = if streak_ids.any?
      Heartbeat.daily_streaks_for_users(streak_ids, start_date: 30.days.ago, exclude_browser_time: true)
    else
      {}
    end

    entries = totals.map do |user_id, seconds|
      entry = LeaderboardEntry.new(
        leaderboard: board,
        user_id: user_id,
        total_seconds: seconds,
        streak_count: streaks[user_id] || 0
      )

      entry.user = users_map[user_id]
      entry
    end.sort_by(&:total_seconds).reverse

    board.define_singleton_method(:entries) { entries }
    board.define_singleton_method(:scope_name) { scope }

    board
  end
end
