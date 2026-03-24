class CreateHeartbeats < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS heartbeats
      (
          id Int64,
          user_id Int64,
          branch String DEFAULT '',
          category String DEFAULT '',
          dependencies Array(String),
          editor String DEFAULT '',
          entity String DEFAULT '',
          language String DEFAULT '',
          machine String DEFAULT '',
          operating_system String DEFAULT '',
          project String DEFAULT '',
          type String DEFAULT '',
          user_agent String DEFAULT '',
          line_additions Int32 DEFAULT 0,
          line_deletions Int32 DEFAULT 0,
          lineno Int32 DEFAULT 0,
          lines Int32 DEFAULT 0,
          cursorpos Int32 DEFAULT 0,
          project_root_count Int32 DEFAULT 0,
          time Float64,
          is_write UInt8 DEFAULT 0,
          created_at DateTime64(6) DEFAULT now64(),
          updated_at DateTime64(6) DEFAULT now64(),
          source_type UInt8 DEFAULT 0,
          ip_address String DEFAULT '',
          ysws_program UInt8 DEFAULT 0,
          fields_hash String DEFAULT ''
      )
      ENGINE = ReplacingMergeTree()
      PARTITION BY toYYYYMM(toDateTime(toUInt32(time)))
      ORDER BY (user_id, toDate(toDateTime(toUInt32(time))), project, id)
      SETTINGS index_granularity = 8192
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS heartbeats"
  end
end
