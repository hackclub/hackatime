class LeaderboardUpdateJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  # Limits concurrency to 1 job per period/date combination
  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "leaderboard_#{arguments[0] || 'daily'}_#{arguments[1] || Date.current.to_s}" }
  )

  def perform(period = :daily, date = Date.current, force_update: false)
    date = LeaderboardDateRange.normalize_date(date, period)
    build_leaderboard(date, period, force_update)
  end

  private

  def build_leaderboard(date, period, force_update = false)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    board = ::Leaderboard.find_or_create_by!(start_date: date, period_type: period, timezone_utc_offset: nil)
    return board if board.finished_generating_at.present? && !force_update

    Rails.logger.info "Building leaderboard for #{period} on #{date}"

    range = LeaderboardDateRange.calculate(date, period)
    timestamp = Time.current
    eligible_users = User.where.not(github_uid: nil).where.not(trust_level: User.trust_levels[:red])

    ActiveRecord::Base.transaction do
      data = Heartbeat.where(user_id: eligible_users.select(:id), time: range)
                      .leaderboard_eligible
                      .group(:user_id).duration_seconds
                      .filter { |_, seconds| seconds > 60 }

      # Two-phase streak: query 8d first (covers most), extend to 31d for users who maxed it.
      streaks = Heartbeat.daily_streaks_for_users(data.keys, start_date: 8.days.ago, exclude_browser_time: true)
      needs_full_history = streaks.select { |_, s| s >= 6 }.keys
      if needs_full_history.any?
        needs_full_history.each { |id| Rails.cache.delete("user_streak_without_browser_v3_#{id}") }
        streaks.merge!(Heartbeat.daily_streaks_for_users(needs_full_history, start_date: 31.days.ago, exclude_browser_time: true))
      end

      entries = data.map do |user_id, seconds|
        { leaderboard_id: board.id, user_id:, total_seconds: seconds,
          streak_count: streaks[user_id] || 0, created_at: timestamp, updated_at: timestamp }
      end

      LeaderboardEntry.upsert_all(entries, unique_by: %i[leaderboard_id user_id]) if entries.any?

      if data.keys.any?
        board.entries.where.not(user_id: data.keys).delete_all
      else
        board.entries.delete_all
      end

      board.update!(
        finished_generating_at: Time.current,
        generation_duration_seconds: [ (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).ceil, 1 ].max
      )
    end

    LeaderboardCache.write(LeaderboardCache.global_key(period, date), board)
    LeaderboardPageCache.warm(leaderboard: board)
    LeaderboardEntries.warm_public(leaderboard: board)
    Rails.logger.debug "Persisted leaderboard for #{period} with #{board.entries.count} entries"
    board
  end
end
