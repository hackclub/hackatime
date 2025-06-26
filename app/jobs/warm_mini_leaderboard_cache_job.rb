class WarmMiniLeaderboardCacheJob < ApplicationJob
  queue_as :default

  def perform
    offsets = [ -8, -7, -6, -5, -4, -3, 0, 1, 2, 8, 9, 10, 11, 12 ]

    offsets.each do |offset|
      begin
        LeaderboardGenerator.generate_timezone_offset_leaderboard(
          Date.current,
          offset,
          :daily
        )
        Rails.logger.info "Warmed mini leaderboard cache for UTC#{offset >= 0 ? '+' : ''}#{offset}"
      rescue => e
        Rails.logger.error "Failed to warm cache for UTC#{offset >= 0 ? '+' : ''}#{offset}: #{e.message}"
      end
    end
  end
end
