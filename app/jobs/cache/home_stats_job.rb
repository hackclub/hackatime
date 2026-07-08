class Cache::HomeStatsJob < Cache::ActivityJob
  queue_as :latency_5m

  private

  def calculate
    totals = Clickhouse::Heartbeat.duration_seconds(Clickhouse::Heartbeat.group(:user_id))
    totals = totals.select { |_, seconds| seconds >= 1 }
    { users_tracked: totals.size, seconds_tracked: totals.values.sum }
  end
end
