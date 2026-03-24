class CreateHeartbeatUserDailySummary < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS heartbeat_user_daily_summary
      (
          user_id    Int64,
          day        Date,
          duration_s Float64,
          heartbeats UInt32,
          _version   DateTime DEFAULT now()
      )
      ENGINE = ReplacingMergeTree(_version)
      ORDER BY (user_id, day)
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS heartbeat_user_daily_summary"
  end
end
