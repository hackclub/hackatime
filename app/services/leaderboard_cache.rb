module LeaderboardCache
  CACHE_EXPIRATION = 10.minutes

  module_function

  def global_key(period, date)
    "leaderboard_#{period}_#{date}"
  end

  def timezone_key(offset, date, period)
    "tz_leaderboard_#{offset}_#{date}_#{period}"
  end

  def write(key, data)
    Rails.cache.write(key, data, expires_in: CACHE_EXPIRATION)
  end

  def read(key)
    Rails.cache.read(key)
  end

  def fetch(key, &block)
    Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION, &block)
  end
end
