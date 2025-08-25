class LeaderboardUpdateJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  # Limits concurrency to 1 job per period/date combination
  good_job_control_concurrency_with(
    key: -> { "leaderboard_#{arguments[0] || 'daily'}_#{arguments[1] || Date.current.to_s}" },
    total: 1,
    drop: true
  )

  def perform(period = :daily, date = Date.current)
    date = LeaderboardDateRange.normalize_date(date, period)

    Rails.logger.info "Starting leaderboard generation for #{period} on #{date}"

    board = build_global(date, period)
    build_timezones(date, period)

    Rails.logger.info "Completed leaderboard generation for #{period} on #{date}"

    board
  rescue => e
    Rails.logger.error "Failed to update leaderboard: #{e.message}"
    Honeybadger.notify(e, context: { period: period, date: date })
    raise
  end

  private

  def build_global(date, period)
    range = LeaderboardDateRange.calculate(date, period)
    board = ::Leaderboard.find_or_create_by!(
      start_date: date,
      period_type: period,
      timezone_utc_offset: nil
    )

    return board if board.finished_generating_at.present?

    ActiveRecord::Base.transaction do
      board.entries.delete_all
      data = Heartbeat.where(time: range)
                     .with_valid_timestamps
                     .joins(:user)
                     .coding_only
                     .where.not(users: { github_uid: nil })
                     .group(:user_id)
                     .duration_seconds

      data = data.filter { |_, seconds| seconds > 60 }

      convicted = User.where(trust_level: User.trust_levels[:red]).pluck(:id)
      data = data.reject { |user_id, _| convicted.include?(user_id) }

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

    key = LeaderboardCache.global_key(period, date)
    LeaderboardCache.write(key, board)

    board
  end

  def build_timezones(date, period)
    range = LeaderboardDateRange.calculate(date, period)

    user_timezones = User.joins(:heartbeats)
                      .where(heartbeats: { time: range })
                      .where.not(timezone: nil)
                      .distinct
                      .pluck(:timezone)
                      .compact

    offsets = user_timezones.map { |tz| User.timezone_to_utc_offset(tz) }.compact.uniq

    Rails.logger.info "Generating timezone leaderboards for #{offsets.size} active UTC offsets"

    offsets.each do |offset|
      build_timezone(date, period, offset)
    end
  end

  def build_timezone(date, period, offset)
    range = LeaderboardDateRange.calculate(date, period)
    board = ::Leaderboard.find_or_create_by!(
      start_date: date,
      period_type: period,
      timezone_utc_offset: offset
    )

    return board if board.finished_generating_at.present?

    Rails.logger.info "Building timezone leaderboard for UTC#{offset >= 0 ? '+' : ''}#{offset} (#{period}, #{date})"

    ActiveRecord::Base.transaction do
      board.entries.delete_all

      # Get users in this timezone offset
      users_in_tz = User.users_in_timezone_offset(offset).not_convicted
      user_ids = users_in_tz.pluck(:id)

      return board if user_ids.empty?

      data = Heartbeat.where(time: range, user_id: user_ids)
                      .with_valid_timestamps
                      .joins(:user)
                      .coding_only
                      .where.not(users: { github_uid: nil })
                      .group(:user_id)
                      .duration_seconds

      data = data.filter { |_, seconds| seconds > 60 }

      convicted = User.where(trust_level: User.trust_levels[:red]).pluck(:id)
      data = data.reject { |user_id, _| convicted.include?(user_id) }

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

    # Cache the persistent board for faster access
    key = LeaderboardCache.timezone_key(offset, date, period)
    LeaderboardCache.write(key, board)

    Rails.logger.debug "Persisted timezone leaderboard for UTC#{offset >= 0 ? '+' : ''}#{offset} with #{board.entries.count} entries"

    board
  end
end
