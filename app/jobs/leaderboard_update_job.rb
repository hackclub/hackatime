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
    generation_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    board = ::Leaderboard.find_or_create_by!(
      start_date: date,
      period_type: period,
      timezone_utc_offset: nil
    )

    return board if board.finished_generating_at.present? && !force_update

    Rails.logger.info "Building leaderboard for #{period} on #{date}"

    range = LeaderboardDateRange.calculate(date, period)
    timestamp = Time.current
    eligible_users = User.where.not(github_uid: nil)
                         .where.not(trust_level: User.trust_levels[:red])

    ActiveRecord::Base.transaction do
      heartbeat_query = Heartbeat.where(user_id: eligible_users.select(:id), time: range)
                                 .leaderboard_eligible

      data = heartbeat_query.group(:user_id).duration_seconds
                             .filter { |_, seconds| seconds > 60 }

      # Two-phase streak computation: query 8 days of data first (covers
      # most users whose streaks are < 7 days), then extend to 31 days
      # only for users whose streak maxed out the short window.
      # This reduces heartbeat rows scanned from ~7M to ~2M for typical runs.
      streaks = Heartbeat.daily_streaks_for_users(data.keys, start_date: 8.days.ago, exclude_browser_time: true)

      needs_full_history = streaks.select { |_, streak| streak >= 6 }.keys
      if needs_full_history.any?
        needs_full_history.each { |id| Rails.cache.delete("user_streak_without_browser_#{id}") }
        full_streaks = Heartbeat.daily_streaks_for_users(needs_full_history, start_date: 31.days.ago, exclude_browser_time: true)
        streaks.merge!(full_streaks)
      end

      entries = data.map do |user_id, seconds|
        {
          leaderboard_id: board.id,
          user_id: user_id,
          total_seconds: seconds,
          streak_count: streaks[user_id] || 0,
          created_at: timestamp,
          updated_at: timestamp
        }
      end

      LeaderboardEntry.upsert_all(entries, unique_by: %i[leaderboard_id user_id]) if entries.any?

      if data.keys.any?
        board.entries.where.not(user_id: data.keys).delete_all
      else
        board.entries.delete_all
      end

      finished_at = Time.current
      generation_duration_seconds = [
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - generation_started_at).ceil,
        1
      ].max

      board.update!(
        finished_generating_at: finished_at,
        generation_duration_seconds: generation_duration_seconds
      )
    end

    cache_key = LeaderboardCache.global_key(period, date)
    LeaderboardCache.write(cache_key, board)
    LeaderboardPageCache.warm(leaderboard: board)

    Rails.logger.debug "Persisted leaderboard for #{period} with #{board.entries.count} entries"

    board
  end
end
