class LeaderboardUpdateJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  # Limits concurrency to 1 job per period/date combination
  good_job_control_concurrency_with(
    key: -> { "leaderboard_#{arguments[0] || 'daily'}_#{arguments[1] || Date.current.to_s}" },
    total: 1,
    drop: true
  )

  def perform(period = :daily, date = Date.current, force_update: false)
    date = LeaderboardDateRange.normalize_date(date, period)

    # global
    build_leaderboard(date, period, nil, nil, force_update)

    # Build timezone leaderboards
    range = LeaderboardDateRange.calculate(date, period)
    timezones_for_users_in(range).each do |timezone|
      offset = User.timezone_to_utc_offset(timezone)
      build_leaderboard(date, period, offset, timezone, force_update)
    end
  end

  private

  def timezones_for_users_in(range)
    # Expand range by 1 day in both directions to catch users in all timezones
    expanded_range = (range.begin - 1.day)...(range.end + 1.day)

    User.joins(:heartbeats)
        .where(heartbeats: { time: expanded_range })
        .where.not(timezone: nil)
        .distinct
        .pluck(:timezone)
        .compact
  end


  def build_leaderboard(date, period, timezone_offset = nil, timezone = nil, force_update = false)
    board = ::Leaderboard.find_or_create_by!(
      start_date: date,
      period_type: period,
      timezone_utc_offset: timezone_offset
    )

    return board if board.finished_generating_at.present? && !force_update

    if timezone_offset
      Rails.logger.info "Building timezone leaderboard for #{timezone} (UTC#{timezone_offset >= 0 ? '+' : ''}#{timezone_offset})"
    else
      Rails.logger.info "Building global leaderboard"
    end

    # Calculate timezone-aware range
    range = if timezone
      Time.use_zone(timezone) { LeaderboardDateRange.calculate(date, period) }
    else
      LeaderboardDateRange.calculate(date, period)
    end

    ActiveRecord::Base.transaction do
      board.entries.delete_all

      # Build the base heartbeat query
      heartbeat_query = Heartbeat.where(time: range)
                                .with_valid_timestamps
                                .joins(:user)
                                .coding_only
                                .where.not(users: { github_uid: nil })
                                .where.not(users: { trust_level: User.trust_levels[:red] })

      # Filter by timezone if specified
      if timezone_offset
        users_in_tz = User.users_in_timezone_offset(timezone_offset).not_convicted
        user_ids = users_in_tz.pluck(:id)
        return board if user_ids.empty?
        heartbeat_query = heartbeat_query.where(user_id: user_ids)
      end

      data = heartbeat_query.group(:user_id).duration_seconds
                            .filter { |_, seconds| seconds > 60 }

      streaks = Heartbeat.daily_streaks_for_users(data.keys)

      entries = data.map do |user_id, seconds|
        {
          leaderboard_id: board.id,
          user_id: user_id,
          total_seconds: seconds,
          streak_count: streaks[user_id] || 0,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      LeaderboardEntry.insert_all!(entries) if entries.any?
      board.update!(finished_generating_at: Time.current)
    end

    # Cache the board
    cache_key = timezone_offset ?
      LeaderboardCache.timezone_key(timezone_offset, date, period) :
      LeaderboardCache.global_key(period, date)

    LeaderboardCache.write(cache_key, board)

    Rails.logger.debug "Persisted #{timezone_offset ? 'timezone' : 'global'} leaderboard with #{board.entries.count} entries"

    board
  end
end
