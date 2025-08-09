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
    date = date.is_a?(Date) ? date : Date.parse(date.to_s)
    date = date.beginning_of_week if period == :weekly
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
    range = date_range(date, period)
    board = ::Leaderboard.find_or_create_by!(
      start_date: date,
      period_type: period,
      timezone_offset: nil
    ) do |lb|
      lb.finished_generating_at = nil
    end

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

    key = "leaderboard_#{period}_#{date}"
    Rails.cache.write(key, board, expires_in: 10.minutes)

    board
  end

  def build_timezones(date, period)
    range = date_range(date, period)

    offsets = User.joins(:heartbeats)
                  .where(heartbeats: { time: range })
                  .where.not(timezone_utc_offset: nil)
                  .distinct
                  .pluck(:timezone_utc_offset)
                  .compact

    Rails.logger.info "Generating timezone leaderboards for #{offsets.size} active UTC offsets"

    offsets.each do |offset|
      build_timezone(date, period, offset)
    end
  end

  def build_timezone(date, period, offset)
    key = "tz_leaderboard_#{offset}_#{date}_#{period}"

    data = Rails.cache.fetch(key, expires_in: 10.minutes) do
      users = User.users_in_timezone_offset(offset).not_convicted
      build_for_users(users, date, "UTC#{offset >= 0 ? '+' : ''}#{offset}", period)
    end

    Rails.logger.debug "Cached timezone leaderboard for UTC#{offset >= 0 ? '+' : ''}#{offset} with #{data&.entries&.size || 0} entries"

    data
  end

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

    range = date_range(date, period)

    beats = Heartbeat.where(user_id: ids, time: range)
                    .coding_only
                    .with_valid_timestamps
                    .joins(:user)
                    .where.not(users: { github_uid: nil })

    totals = beats.group(:user_id).duration_seconds
    totals = totals.filter { |_, seconds| seconds > 60 }

    streak_ids = totals.keys
    streaks = streak_ids.any? ? Heartbeat.daily_streaks_for_users(streak_ids, start_date: 30.days.ago) : {}

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

  def date_range(date, period)
    case period
    when :weekly
      (date.beginning_of_day...(date + 7.days).beginning_of_day)
    when :last_7_days
      ((date - 6.days).beginning_of_day...date.end_of_day)
    else
      date.all_day
    end
  end
end
