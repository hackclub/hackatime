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
    LeaderboardBuilder.build_for_users(users, date, "UTC#{offset >= 0 ? '+' : ''}#{offset}", period)
  end
end
