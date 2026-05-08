class Leaderboard
  # Internal: builds (or rebuilds) the entries for a Leaderboard row.
  # Use Leaderboard.regenerate(period:, date:) as the public entry point.
  #
  # Responsibilities, all in one place so the build invariants live together:
  #   - Find/create the persisted Leaderboard row for (period, date).
  #   - Aggregate eligible heartbeat durations over the board's range.
  #   - Compute streaks (with a two-phase short/long window optimization).
  #   - Upsert LeaderboardEntries and prune stale ones.
  #   - Mark the board finished and warm both the lookup + page caches.
  class Builder
    MIN_TOTAL_SECONDS = 60
    SHORT_STREAK_WINDOW = 8.days
    FULL_STREAK_WINDOW = 31.days
    SHORT_STREAK_MAX = 6

    def initialize(period:, date:)
      @period = period.to_sym
      @date = Leaderboard.normalize_date(date, @period)
    end

    def call(force: false)
      board = find_or_create_board
      return board if board.finished_generating? && !force

      Rails.logger.info "Building leaderboard for #{@period} on #{@date}"
      generation_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      ActiveRecord::Base.transaction do
        upsert_entries(board)
        finalize(board, generation_started)
      end

      Leaderboard.write_cache(board, period: @period, date: @date)
      LeaderboardPageCache.warm(leaderboard: board)

      Rails.logger.debug "Persisted leaderboard for #{@period} with #{board.entries.count} entries"
      board
    end

    private

    def find_or_create_board
      Leaderboard.find_or_create_by!(
        start_date: @date,
        period_type: @period,
        timezone_utc_offset: nil
      )
    end

    def upsert_entries(board)
      data = heartbeat_durations(board.range)
      streaks = streaks_for(data.keys)
      timestamp = Time.current

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
    end

    def heartbeat_durations(range)
      eligible_users = User.where.not(github_uid: nil)
                           .where.not(trust_level: User.trust_levels[:red])

      Heartbeat.where(user_id: eligible_users.select(:id), time: range)
               .leaderboard_eligible
               .group(:user_id)
               .duration_seconds
               .filter { |_, seconds| seconds > MIN_TOTAL_SECONDS }
    end

    # Two-phase streak computation: query a short window first (covers most
    # users whose streaks are < 7 days), then extend to the full window only
    # for users whose streak maxed out the short window.
    def streaks_for(user_ids)
      return {} if user_ids.empty?

      streaks = Heartbeat.daily_streaks_for_users(
        user_ids,
        start_date: SHORT_STREAK_WINDOW.ago,
        exclude_browser_time: true
      )

      maxed = streaks.select { |_, s| s >= SHORT_STREAK_MAX }.keys
      return streaks if maxed.empty?

      maxed.each { |id| Rails.cache.delete("user_streak_without_browser_v3_#{id}") }
      streaks.merge(
        Heartbeat.daily_streaks_for_users(
          maxed,
          start_date: FULL_STREAK_WINDOW.ago,
          exclude_browser_time: true
        )
      )
    end

    def finalize(board, started_at)
      duration = [
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).ceil,
        1
      ].max
      board.update!(
        finished_generating_at: Time.current,
        generation_duration_seconds: duration
      )
    end
  end
end
