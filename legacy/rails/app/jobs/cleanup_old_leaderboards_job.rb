class CleanupOldLeaderboardsJob < ApplicationJob
  queue_as :literally_whenever # fucking wild that this exists

  def perform
    cutoff = 2.days.ago.beginning_of_day

    old_leaderboards = Leaderboard.where("created_at < ?", cutoff)
    count = old_leaderboards.count
    return if count.zero?

    old_leaderboards.destroy_all # kerblam!

    Rails.logger.info "CleanupOldLeaderboardsJob: Deleted #{count} old leaderboards"
  end
end
