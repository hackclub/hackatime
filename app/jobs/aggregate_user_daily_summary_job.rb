class AggregateUserDailySummaryJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as :latency_5m

  good_job_control_concurrency_with(
    total: 1,
    drop: true
  )

  def perform
    conn = HeartbeatUserDailySummary.connection

    conn.execute(<<~SQL)
      INSERT INTO heartbeat_user_daily_summary (user_id, day, duration_s, heartbeats)
      SELECT
        user_id,
        toDate(toDateTime(toUInt32(time))) AS day,
        sum(
          least(
            time - lagInFrame(time, 1, time) OVER (PARTITION BY user_id, toDate(toDateTime(toUInt32(time))) ORDER BY time ASC ROWS BETWEEN 1 PRECEDING AND CURRENT ROW),
            120
          )
        ) AS duration_s,
        count() AS heartbeats
      FROM heartbeats
      GROUP BY user_id, day
    SQL
  end
end
