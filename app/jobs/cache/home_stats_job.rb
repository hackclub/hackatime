class Cache::HomeStatsJob < Cache::ActivityJob
  queue_as :latency_5m

  private

  def calculate
    result = HeartbeatUserDailySummary.connection.select_one(<<~SQL)
      SELECT
        uniq(user_id) AS users_tracked,
        toInt64(coalesce(sum(duration_s), 0)) AS seconds_tracked
      FROM heartbeat_user_daily_summary FINAL
    SQL

    {
      users_tracked: result["users_tracked"].to_i,
      seconds_tracked: result["seconds_tracked"].to_i
    }
  end
end
