class Cache::HomeStatsJob < Cache::ActivityJob
  queue_as :latency_5m

  private

  def cache_key
    "#{super}/#{summary_refresh_version}"
  end

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

  def summary_refresh_version
    connection = HeartbeatUserDailySummary.connection
    database = connection.select_value("SELECT currentDatabase()")

    connection.select_value(<<~SQL)&.to_i || 0
      SELECT toUnixTimestamp(last_success_time)
      FROM system.view_refreshes
      WHERE database = #{connection.quote(database)}
        AND view = 'heartbeat_user_daily_summary_mv'
      LIMIT 1
    SQL
  rescue StandardError
    0
  end
end
