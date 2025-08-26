class LeaderboardService
  include TimezoneRegions

  def self.get(period: :daily, date: Date.current, offset: nil)
    new.get(period: period, date: date, offset: offset)
  end

  def get(period: :daily, date: Date.current, offset: nil)
    date = Date.current if date.blank?

    if offset.present?
      get_timezone(date, period, offset)
    else
      get_global(date, period)
    end
  end

  private

  def get_timezone(date, period, offset)
    date = LeaderboardDateRange.normalize_date(date, period)
    key = LeaderboardCache.timezone_key(offset, date, period)
    board = LeaderboardCache.read(key)

    return board if board.present?

    board = ::Leaderboard.where.not(finished_generating_at: nil)
                         .find_by(start_date: date, period_type: period, timezone_utc_offset: offset, deleted_at: nil)

    if board.present?
      LeaderboardCache.write(key, board)
      return board
    end

    ::LeaderboardUpdateJob.perform_later(period, date)
    get_global(date, period)
  end

  def get_global(date, period)
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
