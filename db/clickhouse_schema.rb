# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_24_000003) do
  # TABLE: schema_migrations
  # SQL: CREATE TABLE schema_migrations ( `version` String, `active` Int8 DEFAULT 1, `ver` DateTime DEFAULT now() ) ENGINE = ReplacingMergeTree(ver) ORDER BY (version)
  execute <<~SQL
    CREATE TABLE IF NOT EXISTS schema_migrations
    (
      `version` String,
      `active` Int8 DEFAULT 1,
      `ver` DateTime DEFAULT now()
    )
    ENGINE = ReplacingMergeTree(ver)
    ORDER BY (version)
  SQL

  # TABLE: ar_internal_metadata
  # SQL: CREATE TABLE ar_internal_metadata ( `key` String, `value` String, `created_at` DateTime, `updated_at` DateTime ) ENGINE = ReplacingMergeTree(created_at) PARTITION BY key ORDER BY key
  execute <<~SQL
    CREATE TABLE IF NOT EXISTS ar_internal_metadata
    (
      `key` String,
      `value` String,
      `created_at` DateTime,
      `updated_at` DateTime
    )
    ENGINE = ReplacingMergeTree(created_at)
    PARTITION BY key
    ORDER BY key
  SQL

  # TABLE: heartbeat_user_daily_summary
  # SQL: CREATE TABLE heartbeat_user_daily_summary ( `user_id` Int64, `day` Date, `duration_s` Float64, `heartbeats` UInt32, `_version` DateTime DEFAULT now() ) ENGINE = ReplacingMergeTree(_version) ORDER BY (user_id, day) SETTINGS index_granularity = 8192
  execute <<~SQL
    CREATE TABLE IF NOT EXISTS heartbeat_user_daily_summary
    (
      `user_id` Int64,
      `day` Date,
      `duration_s` Float64,
      `heartbeats` UInt32,
      `_version` DateTime DEFAULT now()
    )
    ENGINE = ReplacingMergeTree(_version)
    ORDER BY (user_id, day)
    SETTINGS index_granularity = 8192
  SQL

  # TABLE: heartbeats
  # SQL: CREATE TABLE heartbeats ( `id` Int64, `user_id` Int64, `branch` String DEFAULT '', `category` String DEFAULT '', `dependencies` Array(String), `editor` String DEFAULT '', `entity` String DEFAULT '', `language` String DEFAULT '', `machine` String DEFAULT '', `operating_system` String DEFAULT '', `project` String DEFAULT '', `type` String DEFAULT '', `user_agent` String DEFAULT '', `line_additions` Int32 DEFAULT 0, `line_deletions` Int32 DEFAULT 0, `lineno` Int32 DEFAULT 0, `lines` Int32 DEFAULT 0, `cursorpos` Int32 DEFAULT 0, `project_root_count` Int32 DEFAULT 0, `time` Float64, `is_write` UInt8 DEFAULT 0, `created_at` DateTime64(6) DEFAULT now64(), `updated_at` DateTime64(6) DEFAULT now64(), `source_type` UInt8 DEFAULT 0, `ip_address` String DEFAULT '', `ysws_program` UInt8 DEFAULT 0, `fields_hash` String DEFAULT '' ) ENGINE = ReplacingMergeTree PARTITION BY toYYYYMM(toDateTime(toUInt32(time))) ORDER BY (user_id, toDate(toDateTime(toUInt32(time))), project, id) SETTINGS index_granularity = 8192
  execute <<~SQL
    CREATE TABLE IF NOT EXISTS heartbeats
    (
      `id` Int64,
      `user_id` Int64,
      `branch` String DEFAULT '',
      `category` String DEFAULT '',
      `dependencies` Array(String),
      `editor` String DEFAULT '',
      `entity` String DEFAULT '',
      `language` String DEFAULT '',
      `machine` String DEFAULT '',
      `operating_system` String DEFAULT '',
      `project` String DEFAULT '',
      `type` String DEFAULT '',
      `user_agent` String DEFAULT '',
      `line_additions` Int32 DEFAULT 0,
      `line_deletions` Int32 DEFAULT 0,
      `lineno` Int32 DEFAULT 0,
      `lines` Int32 DEFAULT 0,
      `cursorpos` Int32 DEFAULT 0,
      `project_root_count` Int32 DEFAULT 0,
      `time` Float64,
      `is_write` UInt8 DEFAULT 0,
      `created_at` DateTime64(6) DEFAULT now64(),
      `updated_at` DateTime64(6) DEFAULT now64(),
      `source_type` UInt8 DEFAULT 0,
      `ip_address` String DEFAULT '',
      `ysws_program` UInt8 DEFAULT 0,
      `fields_hash` String DEFAULT ''
    )
    ENGINE = ReplacingMergeTree
    PARTITION BY toYYYYMM(toDateTime(toUInt32(time)))
    ORDER BY (user_id, toDate(toDateTime(toUInt32(time))), project, id)
    SETTINGS index_granularity = 8192
  SQL

  # TABLE: heartbeat_user_daily_summary_mv
  # SQL: CREATE MATERIALIZED VIEW heartbeat_user_daily_summary_mv REFRESH EVERY 10 MINUTE TO heartbeat_user_daily_summary ( `user_id` Int64, `day` Date, `duration_s` Float64, `heartbeats` UInt32 ) AS SELECT user_id, toDate(toDateTime(toUInt32(time))) AS day, sum(diff) AS duration_s, toUInt32(count()) AS heartbeats FROM ( SELECT user_id, time, least(greatest(time - lagInFrame(time, 1, time) OVER (PARTITION BY user_id ORDER BY time ASC ROWS BETWEEN 1 PRECEDING AND CURRENT ROW), 0), 120) AS diff FROM heartbeats FINAL WHERE (time IS NOT NULL) AND (time >= 0) AND (time <= 253402300799) ) GROUP BY user_id, day
  execute <<~SQL
    CREATE MATERIALIZED VIEW IF NOT EXISTS heartbeat_user_daily_summary_mv
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
        FROM heartbeats FINAL
        WHERE time IS NOT NULL
          AND time >= 0
          AND time <= 253402300799
    )
    GROUP BY user_id, day
  SQL
end
