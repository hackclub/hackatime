class Cache::MinutesLoggedJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def calculate
    StatsClient.duration(
      start_time: 1.hour.ago.to_f,
      end_time: Time.current.to_f,
      coding_only: true
    )["total_seconds"].to_i / 60
  end
end
