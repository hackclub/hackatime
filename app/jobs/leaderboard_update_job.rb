class LeaderboardUpdateJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency
  ENTRY_INSERT_BATCH_SIZE = ENV.fetch("LEADERBOARD_ENTRY_INSERT_BATCH_SIZE", 800).to_i

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
    build_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    board = ::Leaderboard.find_or_create_by!(
      start_date: date,
      period_type: period,
      timezone_utc_offset: nil
    )

    return board if board.finished_generating_at.present? && !force_update

    Rails.logger.info "Building leaderboard for #{period} on #{date}"

    range = LeaderboardDateRange.calculate(date, period)
    now = Time.current
    entries_count = 0

    eligible_user_ids = User.where.not(github_uid: nil)
                            .where.not(trust_level: User.trust_levels[:red])
                            .select(:id)

    ActiveRecord::Base.transaction do
      # Build the base heartbeat query
      heartbeat_query = Heartbeat.where(time: range)
                                 .with_valid_timestamps
                                 .coding_only
                                 .where(user_id: eligible_user_ids)

      data = heartbeat_query.group(:user_id)
                            .duration_seconds(minimum_seconds: 60)

      streaks = data.keys.any? ? Heartbeat.daily_streaks_for_users(data.keys) : {}

      entries = data.map do |user_id, seconds|
        {
          leaderboard_id: board.id,
          user_id: user_id,
          total_seconds: seconds,
          streak_count: streaks[user_id] || 0,
          created_at: now,
          updated_at: now
        }
      end

      board.entries.delete_all
      entries.each_slice(ENTRY_INSERT_BATCH_SIZE) do |entry_batch|
        LeaderboardEntry.insert_all(entry_batch) if entry_batch.any?
      end

      board.update!(finished_generating_at: now)
      entries_count = entries.length
    end

    # Cache the board
    cache_key = LeaderboardCache.global_key(period, date)
    LeaderboardCache.write(cache_key, board)

    build_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - build_started_at
    Rails.logger.info("Persisted leaderboard for #{period} with #{entries_count} entries in #{build_elapsed.round(2)}s")

    board
  end
end
