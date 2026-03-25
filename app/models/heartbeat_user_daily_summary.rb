class HeartbeatUserDailySummary < ClickhouseRecord
  self.table_name = "heartbeat_user_daily_summary"

  VIEW_NAME = "heartbeat_user_daily_summary_mv".freeze

  class << self
    def duration_for_days(user_id:, days:)
      return 0 if days.empty?

      from("#{table_name} FINAL")
        .where(user_id: user_id, day: days.uniq.sort)
        .sum(:duration_s)
        .to_i
    end

    def last_refresh_time
      database = connection.select_value("SELECT currentDatabase()")

      connection.select_value(<<~SQL)
        SELECT last_success_time
        FROM system.view_refreshes
        WHERE database = #{connection.quote(database)}
          AND view = #{connection.quote(VIEW_NAME)}
        LIMIT 1
      SQL
    rescue StandardError
      nil
    end
  end
end
