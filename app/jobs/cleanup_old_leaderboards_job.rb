class CleanupOldLeaderboardsJob < ApplicationJob
  queue_as :literally_whenever # fucking wild that this exists

  # `RETAIN_DAYS = 2` keeps today + 2 prior days of boards (3 dates total)
  # before reaping older ones. Boards with `start_date < (today - 2)` go.
  RETAIN_DAYS = 2

  def perform
    cutoff = RETAIN_DAYS.days.ago.to_date

    old_leaderboards = Leaderboard.where(start_date: ...cutoff)
    count = old_leaderboards.count
    return if count.zero?

    old_leaderboards.destroy_all # kerblam!

    Rails.logger.info "CleanupOldLeaderboardsJob: Deleted #{count} old leaderboards"
  end
end
