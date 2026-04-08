class Cache::HomeStatsJob < Cache::ActivityJob
  queue_as :latency_5m

  private

  def cache_expiration
    12.hours
  end

  def calculate
    timeout = Heartbeat.heartbeat_timeout_duration.to_i
    raw_durations = Heartbeat.with_valid_timestamps.select(
      :user_id,
      Arel.sql(<<~SQL.squish)
        CASE
          WHEN LAG(time) OVER (PARTITION BY user_id ORDER BY time) IS NULL THEN 0
          ELSE LEAST(time - LAG(time) OVER (PARTITION BY user_id ORDER BY time), #{timeout})
        END AS diff
      SQL
    )
    totals = Heartbeat.connection.select_one(<<~SQL.squish)
      SELECT
        COUNT(DISTINCT user_id) AS users_tracked,
        COALESCE(SUM(diff), 0)::bigint AS seconds_tracked
      FROM (#{raw_durations.to_sql}) AS heartbeat_stats
    SQL

    {
      users_tracked: totals["users_tracked"].to_i,
      seconds_tracked: totals["seconds_tracked"].to_i
    }
  end
end
