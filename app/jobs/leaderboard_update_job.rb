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
    result = StatsClient.leaderboard_compute(
      start_time: range.first,
      end_time: range.last,
      min_seconds: 60,
      include_streaks: true,
      coding_only: true,
      exclude_trust_level_red: true,
      require_github_uid: true
    )
    entry_rows = result["entries"] || []

    ActiveRecord::Base.transaction do
      entries = entry_rows.map do |entry|
        {
          leaderboard_id: board.id,
          user_id: entry["user_id"],
          total_seconds: entry["total_seconds"],
          streak_count: entry["streak_count"] || 0,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      LeaderboardEntry.upsert_all(entries, unique_by: %i[leaderboard_id user_id]) if entries.any?

      entry_user_ids = entry_rows.map { |entry| entry["user_id"] }
      if entry_user_ids.any?
        board.entries.where.not(user_id: entry_user_ids).delete_all
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
