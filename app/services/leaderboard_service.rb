class LeaderboardService
  def self.get(period: :daily, date: Date.current)
    new.get(period: period, date: date)
  end

  def get(period: :daily, date: Date.current)
    date = Date.current if date.blank?
    date = LeaderboardDateRange.normalize_date(date, period)

    key = LeaderboardCache.global_key(period, date)
    board = LeaderboardCache.read(key)
    return board if board.present?

    board = ::Leaderboard.where.not(finished_generating_at: nil)
                         .find_by(start_date: date, period_type: period, timezone_utc_offset: nil, deleted_at: nil)

    if board.present?
      LeaderboardCache.write(key, board)
      return board
    end

    ::LeaderboardUpdateJob.perform_later(period, date)
    nil
  end
end
