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
    build_leaderboard(date, period, force_update)
  end

  private

  def build_leaderboard(date, period, force_update = false)
    board = ::Leaderboard.find_or_create_by!(
      start_date: date,
      period_type: period,
      timezone_utc_offset: nil
    )

    return board if board.finished_generating_at.present? && !force_update

    Rails.logger.info "Building leaderboard for #{period} on #{date}"

    range = LeaderboardDateRange.calculate(date, period)

    ActiveRecord::Base.transaction do
      # Build the base heartbeat query
      heartbeat_query = Heartbeat.where(time: range)
                                 .with_valid_timestamps
                                 .joins(:user)
                                 .coding_only
                                 .where.not(users: { github_uid: nil })
                                 .where.not(users: { trust_level: User.trust_levels[:red] })

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

      LeaderboardEntry.insert_all!(entries, on_duplicate: :update, update_only: %i[total_seconds streak_count updated_at]) if entries.any?

      if data.keys.any?
        board.entries.where.not(user_id:  data.keys).delete_all
      else
        board.entries.delete_all
      end

      board.update!(finished_generating_at: Time.current)
    end

    # Cache the board
    cache_key = LeaderboardCache.global_key(period, date)
    LeaderboardCache.write(cache_key, board)

    Rails.logger.debug "Persisted leaderboard for #{period} with #{board.entries.count} entries"

    board
  end
end
