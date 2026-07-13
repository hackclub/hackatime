class Cache::HomeStatsJob < Cache::ActivityJob
  queue_as :latency_5m

  private

  def calculate
    row = Clickhouse::HeartbeatUserDailyStat.connection.select_one(<<~SQL.squish)
      SELECT countIf(duration >= 1) AS users_tracked,
             sumIf(duration, duration >= 1) AS seconds_tracked
      FROM (
        SELECT user_id, sum(seconds) AS duration
        FROM #{Clickhouse::HeartbeatUserDailyStat.table_name}
        GROUP BY user_id
      ) AS user_durations
    SQL

    { users_tracked: row["users_tracked"].to_i, seconds_tracked: row["seconds_tracked"].to_i }
  end
end
