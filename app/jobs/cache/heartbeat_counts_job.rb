class Cache::HeartbeatCountsJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def calculate
    direct = Heartbeat.source_types.fetch("direct_entry")
    recent_count, recent_imported_count = Heartbeat.recent.pluck(
      Arel.sql("COUNT(*) AS recent_count"),
      Arel.sql("COUNT(*) FILTER (WHERE source_type != #{direct}) AS recent_imported_count")
    ).first
    { recent_count:, recent_imported_count: }
  end
end
