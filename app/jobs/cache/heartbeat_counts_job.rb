class Cache::HeartbeatCountsJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def calculate
    direct = Clickhouse::Heartbeat.source_types.fetch("direct_entry")
    recent_count, recent_imported_count = Clickhouse::Heartbeat.recent.pluck(
      Arel.sql("COUNT(*)"),
      Arel.sql("countIf(source_type != #{direct})")
    ).first
    { recent_count:, recent_imported_count: }
  rescue ActiveRecord::ActiveRecordError => e
    raise unless e.message.include?("undefined method 'map' for nil")

    { recent_count: 0, recent_imported_count: 0 }
  end
end
