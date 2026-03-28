class Cache::HomeStatsJob < Cache::ActivityJob
  queue_as :latency_5m

  private

  def calculate
    seconds_by_user = StatsClient.duration_grouped(group_by: "user_id")["groups"] || {}
    {
      users_tracked: seconds_by_user.size,
      seconds_tracked: seconds_by_user.values.sum(&:to_i)
    }
  end
end
