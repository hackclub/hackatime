module LeaderboardCache
  CACHE_EXPIRATION = 10.minutes

  module_function

  def global_key(period, date)
    "leaderboard_#{period}_#{date}"
  end

  def write(key, data)
    Rails.cache.write(key, data, expires_in: CACHE_EXPIRATION)
  end

  def read(key)
    Rails.cache.read(key)
  end
end
