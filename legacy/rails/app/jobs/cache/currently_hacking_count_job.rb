class Cache::CurrentlyHackingCountJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def cache_expiration = 1.minute

  def calculate
    count = Heartbeat.joins(:user).where(source_type: :direct_entry).coding_only
      .where("time > ?", 5.minutes.ago.to_f).select("DISTINCT user_id").count
    { count: count }
  end
end
