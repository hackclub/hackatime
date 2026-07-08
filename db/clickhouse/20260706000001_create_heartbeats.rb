class CreateHeartbeats < ActiveRecord::Migration[8.1]
  def change
    create_table :heartbeats,
      id: false,
      options: "ReplacingMergeTree(version) " \
               "PARTITION BY toYYYYMM(toDateTime(time)) " \
               "ORDER BY (user_id, time, fields_hash) " \
               "SETTINGS index_granularity = 8192" do |t|
      t.column :id, "UInt64", null: false, codec: "Delta(8), LZ4"
      t.column :user_id, "UInt32", null: false, codec: "T64, ZSTD(1)"
      t.column :time, "Float64", null: false, codec: "Gorilla, ZSTD(1)"
      t.column :project, "String", codec: "ZSTD(3)"
      t.column :branch, "String", codec: "ZSTD(3)"
      t.column :category, "String", low_cardinality: true, codec: "ZSTD(1)"
      t.column :editor, "String", low_cardinality: true, codec: "ZSTD(1)"
      t.column :entity, "String", codec: "ZSTD(3)"
      t.column :language, "String", low_cardinality: true, codec: "ZSTD(1)"
      t.column :machine, "String", low_cardinality: true, codec: "ZSTD(1)"
      t.column :operating_system, "String", low_cardinality: true, codec: "ZSTD(1)"
      t.column :user_agent, "String", codec: "ZSTD(3)"
      t.column :lineno, "Int32", codec: "T64, ZSTD(1)"
      t.column :lines, "Int32", codec: "T64, ZSTD(1)"
      t.column :cursorpos, "Int32", codec: "T64, ZSTD(1)"
      t.column :line_additions, "Int32", codec: "T64, ZSTD(1)"
      t.column :line_deletions, "Int32", codec: "T64, ZSTD(1)"
      t.column :project_root_count, "Int32", codec: "T64, ZSTD(1)"
      t.column :is_write, "Bool"
      t.column :source_type, "UInt8", null: false, codec: "T64, ZSTD(1)"
      t.column :ip_address, "String", codec: "ZSTD(1)"
      t.column :dependencies, "String", array: true, null: false, codec: "ZSTD(3)"
      t.column :ja4_id, "Int32", codec: "T64, ZSTD(1)"
      t.column :fields_hash, "FixedString(32)", null: false, codec: "ZSTD(1)"
      t.column :deleted_at, "DateTime64(6, 'UTC')", codec: "Delta(8), ZSTD(1)"
      t.column :created_at, "DateTime64(6, 'UTC')", null: false, codec: "Delta(8), ZSTD(1)"
      t.column :updated_at, "DateTime64(6, 'UTC')", null: false, codec: "Delta(8), ZSTD(1)"
      t.column :version, "UInt64", null: false, codec: "Delta(8), ZSTD(1)"
    end
  end
end
