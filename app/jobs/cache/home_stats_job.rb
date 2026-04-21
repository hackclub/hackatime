class Cache::HomeStatsJob < Cache::ActivityJob
  queue_as :latency_5m

  private

  def calculate
    totals = DashboardRollup.where(dimension: DashboardRollup::TOTAL_DIMENSION)
    active_totals = totals.where("total_seconds > 0")

    {
      users_tracked: active_totals.count,
      seconds_tracked: active_totals.sum(:total_seconds)
    }
  end
end
