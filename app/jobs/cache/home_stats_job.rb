class Cache::HomeStatsJob < Cache::ActivityJob
  queue_as :latency_5m

  private

  def calculate
    timeout = Clickhouse::Heartbeat.heartbeat_timeout_duration.to_i
    lag_sql = "lagInFrame(time, 1, time) OVER (" \
      "PARTITION BY user_id ORDER BY time, id " \
      "ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)"
    relation_sql = Clickhouse::Heartbeat.with_valid_timestamps.select(:user_id, :id, :time).to_sql

    row = Clickhouse::Heartbeat.connection.select_one(<<~SQL.squish)
      SELECT countIf(duration >= 1) AS users_tracked,
             sumIf(duration, duration >= 1) AS seconds_tracked
      FROM (
        SELECT user_id, round(SUM(diff)) AS duration
        FROM (
          SELECT user_id,
                 least(time - #{lag_sql}, #{timeout}) AS diff
          FROM (#{relation_sql}) AS home_stats_heartbeats
        ) AS diffs
        GROUP BY user_id
      ) AS user_durations
    SQL

    { users_tracked: row["users_tracked"].to_i, seconds_tracked: row["seconds_tracked"].to_i }
  end
end
