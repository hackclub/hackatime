class CleanupOldLeaderboardsJob < ApplicationJob
  queue_as :literally_whenever # fucking wild that this exists

  def perform
    cutoff = 2.days.ago.beginning_of_day

    old_leaderboards = Leaderboard.where("created_at < ?", cutoff)
                                  .where(deleted_at: nil)

    return if old_leaderboards.empty?

    old_leaderboards.update_all(deleted_at: Time.current)

    Rails.logger.info "CleanupOldLeaderboardsJob: Marked #{old_leaderboards.count} old leaderboards as deleted"
    Leaderboard.where("created_at < ?", cutoff).where.not(deleted_at: nil).destroy_all
  end
end
