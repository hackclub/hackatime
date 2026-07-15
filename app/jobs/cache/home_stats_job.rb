class Cache::HomeStatsJob < Cache::ActivityJob
  queue_as :latency_5m

  private

  def calculate
    Clickhouse::StatsReader.home_totals
  end
end
