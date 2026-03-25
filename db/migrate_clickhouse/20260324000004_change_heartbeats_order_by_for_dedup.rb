class ChangeHeartbeatsOrderByForDedup < ActiveRecord::Migration[8.1]
  SOURCE_TABLE = "heartbeats".freeze
  TEMP_TABLE = "heartbeats_rebuild_new".freeze
  BACKUP_TABLE = "heartbeats_rebuild_old".freeze
  SUMMARY_VIEW = "heartbeat_user_daily_summary_mv".freeze
  PARTITION_BY = "toYYYYMM(toDateTime(toUInt32(time)))".freeze

  def up
    rebuild_heartbeats_table(
      order_by: "(user_id, toDate(toDateTime(toUInt32(time))), project, entity, time)"
    )
  end

  def down
    rebuild_heartbeats_table(
      order_by: "(user_id, toDate(toDateTime(toUInt32(time))), project, id)"
    )
  end

  private

  def rebuild_heartbeats_table(order_by:)
    drop_summary_view
    drop_rebuild_tables

    execute <<~SQL
      CREATE TABLE #{TEMP_TABLE}
      AS #{SOURCE_TABLE}
      ENGINE = ReplacingMergeTree()
      PARTITION BY #{PARTITION_BY}
      ORDER BY #{order_by}
      SETTINGS index_granularity = 8192
    SQL

    execute <<~SQL
      INSERT INTO #{TEMP_TABLE}
      SELECT *
      FROM #{SOURCE_TABLE}
    SQL

    execute <<~SQL
      RENAME TABLE
        #{SOURCE_TABLE} TO #{BACKUP_TABLE},
        #{TEMP_TABLE} TO #{SOURCE_TABLE}
    SQL

    execute "DROP TABLE IF EXISTS #{BACKUP_TABLE}"
    recreate_summary_view
  rescue StandardError
    recreate_summary_view if show_create_statement(SUMMARY_VIEW).blank?
    raise
  end

  def drop_summary_view
    execute "DROP VIEW IF EXISTS #{SUMMARY_VIEW}"
  end

  def drop_rebuild_tables
    execute "DROP TABLE IF EXISTS #{TEMP_TABLE}"
    execute "DROP TABLE IF EXISTS #{BACKUP_TABLE}"
  end

  def recreate_summary_view
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS #{SUMMARY_VIEW}
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
                          PARTITION BY user_id, toDate(toDateTime(toUInt32(time)))
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

  def show_create_statement(name)
    select_one("SHOW CREATE TABLE #{name}")&.fetch("statement")
  rescue ActiveRecord::ActiveRecordError
    nil
  end
end
