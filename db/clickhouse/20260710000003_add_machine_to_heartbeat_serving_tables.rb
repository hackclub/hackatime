class AddMachineToHeartbeatServingTables < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      ALTER TABLE heartbeat_interval_deltas
      ADD COLUMN machine LowCardinality(String) DEFAULT '' CODEC(ZSTD(1)) AFTER operating_system
    SQL

    execute <<~SQL
      ALTER TABLE heartbeat_interval_deltas
      ADD COLUMN machine_seconds_delta Int64 DEFAULT 0 CODEC(T64, ZSTD(1)) AFTER operating_system_seconds_delta
    SQL

    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_machine_daily_stats
      TO heartbeat_dimension_daily_stats
      AS
      SELECT user_id,
             'machine' AS dimension,
             machine AS value,
             day,
             sum(machine_seconds_delta) AS seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE machine != ''
      GROUP BY user_id, dimension, value, day
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS mv_heartbeat_machine_daily_stats"
    execute "ALTER TABLE heartbeat_interval_deltas DROP COLUMN IF EXISTS machine_seconds_delta"
    execute "ALTER TABLE heartbeat_interval_deltas DROP COLUMN IF EXISTS machine"
  end
end
