class TimezoneLeaderboardJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  # Limits concurrency to 1 job per timezone/period/date combination
  good_job_control_concurrency_with(
    key: -> { "timezone_#{arguments[0]}_#{arguments[1]}_#{arguments[2]}" },
    total: 1,
    drop: true
  )

  def perform(period = :daily, date = Date.current, offset = 0)
    date = LeaderboardDateRange.normalize_date(date, period)

    Rails.logger.info "Generating timezone leaderboard for UTC#{offset >= 0 ? '+' : ''}#{offset} (#{period}, #{date})"

    key = LeaderboardCache.timezone_key(offset, date, period)

    # Generate the leaderboard
    board = build_timezone(date, period, offset)

    # Cache it for 10 minutes
    LeaderboardCache.write(key, board)

    Rails.logger.info "Cached timezone leaderboard for UTC#{offset >= 0 ? '+' : ''}#{offset} with #{board&.entries&.size || 0} entries"

    board
  rescue => e
    Rails.logger.error "Failed to generate timezone leaderboard for UTC#{offset}: #{e.message}"
    Honeybadger.notify(e, context: { period: period, date: date, offset: offset })
    raise
  end

  private

  def build_timezone(date, period, offset)
    users = User.users_in_timezone_offset(offset).not_convicted
    build_for_users(users, date, "UTC#{offset >= 0 ? '+' : ''}#{offset}", period)
  end

  def build_for_users(users, date, scope, period)
    date = Date.current if date.blank?

    # Create a virtual leaderboard object (not saved to DB)
    board = ::Leaderboard.new(
      start_date: date,
      period_type: period,
      finished_generating_at: Time.current
    )

    ids = users.pluck(:id)
    return board if ids.empty?

    # Preload users into a hash for O(1) lookups
    users_map = users.index_by(&:id)

    # Calculate date range
    range = LeaderboardDateRange.calculate(date, period)

    # Get heartbeats efficiently
    beats = Heartbeat.where(user_id: ids, time: range)
                    .coding_only
                    .with_valid_timestamps
                    .joins(:user)
                    .where.not(users: { github_uid: nil })

    # Group by user and calculate totals
    totals = beats.group(:user_id).duration_seconds
    totals = totals.filter { |_, seconds| seconds > 60 }

    # Calculate streaks only for users with time
    streak_ids = totals.keys
    streaks = streak_ids.any? ? Heartbeat.daily_streaks_for_users(streak_ids, start_date: 30.days.ago) : {}

    # Create virtual leaderboard entries
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

    # Attach entries to leaderboard
    board.define_singleton_method(:entries) { entries }
    board.define_singleton_method(:scope_name) { scope }

    board
  end
end
