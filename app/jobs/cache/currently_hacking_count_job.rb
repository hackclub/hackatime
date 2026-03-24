class Cache::CurrentlyHackingCountJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def cache_expiration
    1.minute
  end

  def calculate
    count = Heartbeat.where(source_type: :direct_entry)
                    .coding_only
                    .where("time > ?", 5.minutes.ago.to_f)
                    .distinct
                    .count(:user_id)

    { count: count }
  end
end
