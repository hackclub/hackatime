class Cache::HeartbeatCountsJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def calculate
    direct_entry_source_type = Heartbeat.source_types.fetch("direct_entry")

    recent_count, recent_imported_count = Heartbeat.recent.pluck(
      Arel.sql("COUNT(*)"),
      Arel.sql("COUNT(*) FILTER (WHERE source_type != #{direct_entry_source_type})")
    ).first

    {
      recent_count:,
      recent_imported_count:
    }
  end
end
