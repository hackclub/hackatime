class Cache::HeartbeatCountsJob < Cache::ActivityJob
  queue_as :latency_10s

  def expires_in
    1.hour
  end

  private

  def calculate
    recent_count, recent_imported_count = Heartbeat.recent.pluck(
      Arel.sql("COUNT(*)"),
      Arel.sql("COUNT(*) FILTER (WHERE source_type != 0)")
    ).first

    {
      recent_count:,
      recent_imported_count:
    }
  end
end
