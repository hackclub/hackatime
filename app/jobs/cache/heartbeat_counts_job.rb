class Cache::HeartbeatCountsJob < Cache::ActivityJob
  queue_as :latency_10s

  def expires_in
    5.hours
  end

  private

  def calculate
    {
      recent_count: recent_count,
      recent_imported_count: recent_imported_count
    }
  end

  def recent_count
    Heartbeat.recent.count
  end

  def recent_imported_count
    Heartbeat.recent.where.not(source_type: :direct_entry).count
  end
end
