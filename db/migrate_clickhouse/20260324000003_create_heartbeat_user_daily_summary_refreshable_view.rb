class CreateHeartbeatUserDailySummaryRefreshableView < ActiveRecord::Migration[8.1]
  VIEW_NAME = "heartbeat_user_daily_summary_mv".freeze

  def up
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS #{VIEW_NAME}
      REFRESH EVERY 10 MINUTE
      TO heartbeat_user_daily_summary
      AS
      SELECT
          user_id,
          toDate(toDateTime(toUInt32(time))) AS day,
          sum(diff) AS duration_s,
          toUInt32(count()) AS heartbeats
      FROM
      (
          SELECT
              user_id,
              time,
              least(
                  greatest(
                      time - lagInFrame(time, 1, time) OVER (
                          PARTITION BY user_id
                          ORDER BY time ASC
                          ROWS BETWEEN 1 PRECEDING AND CURRENT ROW
                      ),
                      0
                  ),
                  120
              ) AS diff
          FROM heartbeats
          WHERE time IS NOT NULL
            AND time >= 0
            AND time <= 253402300799
      )
      GROUP BY user_id, day
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS #{VIEW_NAME}"
  end
end
