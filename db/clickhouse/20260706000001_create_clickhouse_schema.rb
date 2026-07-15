class CreateClickhouseSchema < ActiveRecord::Migration[8.1]
  def up
    create_or_adopt_heartbeats
    create_serving_tables
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "ClickHouse heartbeat data must never be dropped by an application migration"
  end

  private

  def create_or_adopt_heartbeats
    if table_exists?(:heartbeats)
      adopt_existing_heartbeats
      return
    end

    execute <<~SQL
      CREATE TABLE heartbeats
      (
          id                 UInt64                             CODEC(Delta(8), LZ4),
          user_id            UInt32                             CODEC(T64, ZSTD(1)),
          time               Float64                            CODEC(Gorilla, ZSTD(1)),
          fields_hash        String                             CODEC(ZSTD(1)),
          project            Nullable(String)                   CODEC(ZSTD(3)),
          branch             Nullable(String)                   CODEC(ZSTD(3)),
          entity             Nullable(String)                   CODEC(ZSTD(3)),
          category           LowCardinality(Nullable(String))   CODEC(ZSTD(1)),
          editor             LowCardinality(Nullable(String))   CODEC(ZSTD(1)),
          language           LowCardinality(Nullable(String))   CODEC(ZSTD(1)),
          machine            LowCardinality(Nullable(String))   CODEC(ZSTD(1)),
          operating_system   LowCardinality(Nullable(String))   CODEC(ZSTD(1)),
          type               LowCardinality(Nullable(String))   CODEC(ZSTD(1)),
          user_agent         Nullable(String)                   CODEC(ZSTD(3)),
          ip_address         Nullable(String)                   CODEC(ZSTD(1)),
          dependencies       Array(String)                      CODEC(ZSTD(3)),
          lineno             Nullable(Int32)                    CODEC(T64, ZSTD(1)),
          lines              Nullable(Int32)                    CODEC(T64, ZSTD(1)),
          cursorpos          Nullable(Int32)                    CODEC(T64, ZSTD(1)),
          line_additions     Nullable(Int32)                    CODEC(T64, ZSTD(1)),
          line_deletions     Nullable(Int32)                    CODEC(T64, ZSTD(1)),
          project_root_count Nullable(Int32)                    CODEC(T64, ZSTD(1)),
          is_write           Nullable(Bool)                     CODEC(ZSTD(1)),
          source_type        UInt8                              CODEC(T64, ZSTD(1)),
          ysws_program       UInt8 DEFAULT 0                    CODEC(T64, ZSTD(1)),
          ja4_id             Nullable(Int32)                    CODEC(T64, ZSTD(1)),
          deleted_at         Nullable(DateTime64(6, 'UTC'))     CODEC(Delta(8), ZSTD(1)),
          created_at         DateTime64(6, 'UTC')               CODEC(Delta(8), ZSTD(1)),
          updated_at         DateTime64(6, 'UTC')               CODEC(Delta(8), ZSTD(1)),
          version            UInt64                             CODEC(T64, ZSTD(1))
      )
      ENGINE = ReplacingMergeTree(version)
      PARTITION BY toYYYYMM(toDateTime(time))
      PRIMARY KEY (user_id, time)
      ORDER BY (user_id, time, fields_hash)
      SETTINGS index_granularity = 8192
    SQL
  end

  def adopt_existing_heartbeats
    columns = connection.columns(:heartbeats).map(&:name)
    # An existing replicated source table can be used read-only while the
    # serving tables are backfilled. Native writes begin only after that table
    # has been cut over to the canonical schema created above.
    required = %w[
      id user_id time fields_hash project branch entity category editor language
      machine operating_system deleted_at created_at updated_at
    ]
    missing = required - columns
    raise "Existing ClickHouse heartbeats table is missing required columns: #{missing.join(', ')}" if missing.any?

    engine = connection.select_value(<<~SQL.squish)
      SELECT engine_full
      FROM system.tables
      WHERE database = currentDatabase() AND name = 'heartbeats'
    SQL
    unless engine.start_with?("ReplacingMergeTree(")
      raise "Refusing to adopt ClickHouse heartbeats with incompatible engine #{engine.inspect}"
    end
  end

  def create_serving_tables
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS heartbeat_interval_deltas
      (
          delta_id UInt64 CODEC(Delta(8), LZ4),
          user_id UInt32 CODEC(T64, ZSTD(1)),
          day Date CODEC(Delta(2), ZSTD(1)),
          time Float64 CODEC(Gorilla, ZSTD(1)),
          project LowCardinality(String) CODEC(ZSTD(1)),
          language LowCardinality(String) CODEC(ZSTD(1)),
          editor LowCardinality(String) CODEC(ZSTD(1)),
          operating_system LowCardinality(String) CODEC(ZSTD(1)),
          machine LowCardinality(String) DEFAULT '' CODEC(ZSTD(1)),
          category LowCardinality(String) CODEC(ZSTD(1)),
          entity String CODEC(ZSTD(3)),
          branch String CODEC(ZSTD(3)),
          user_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          user_first_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          project_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          project_first_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          language_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          language_first_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          editor_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          editor_first_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          operating_system_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          operating_system_first_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          machine_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          machine_first_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          category_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          category_first_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          entity_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          entity_first_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          branch_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          branch_first_seconds_delta Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          heartbeat_count_delta Int64 CODEC(T64, ZSTD(1)),
          reason LowCardinality(String) CODEC(ZSTD(1)),
          created_at DateTime64(6, 'UTC') CODEC(Delta(8), ZSTD(1))
      )
      ENGINE = MergeTree
      PARTITION BY toYYYYMM(day)
      PRIMARY KEY (user_id, day)
      ORDER BY (user_id, day, time, delta_id)
      SETTINGS index_granularity = 8192
    SQL

    create_daily_table("heartbeat_user_daily_stats", "user_id UInt32 CODEC(T64, ZSTD(1))", "(user_id, day)")
    create_daily_table(
      "heartbeat_project_daily_stats",
      "user_id UInt32 CODEC(T64, ZSTD(1)), project LowCardinality(String) CODEC(ZSTD(1))",
      "(user_id, project, day)"
    )
    create_dimension_table("heartbeat_dimension_daily_stats", project: false)
    create_dimension_table("heartbeat_dimension_attribution_daily_stats", project: false)
    create_dimension_table("heartbeat_project_dimension_daily_stats", project: true)

    execute <<~SQL
      CREATE TABLE IF NOT EXISTS heartbeat_project_summaries
      (
          user_id UInt32 CODEC(T64, ZSTD(1)),
          project LowCardinality(String) CODEC(ZSTD(1)),
          seconds Float64 CODEC(Gorilla, ZSTD(1)),
          heartbeat_count Int64 CODEC(T64, ZSTD(1))
      )
      ENGINE = SummingMergeTree
      PRIMARY KEY (user_id, project)
      ORDER BY (user_id, project)
      SETTINGS index_granularity = 8192
    SQL
  end

  def create_daily_table(name, dimensions, order_by)
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS #{name}
      (
          #{dimensions},
          day Date CODEC(Delta(2), ZSTD(1)),
          seconds Float64 CODEC(Gorilla, ZSTD(1)),
          first_seconds Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          heartbeat_count Int64 CODEC(T64, ZSTD(1))
      )
      ENGINE = SummingMergeTree
      PARTITION BY toYYYYMM(day)
      PRIMARY KEY #{order_by}
      ORDER BY #{order_by}
      SETTINGS index_granularity = 8192
    SQL
  end

  def create_dimension_table(name, project:)
    project_column = "project LowCardinality(String) CODEC(ZSTD(1))," if project
    order_by = project ? "(user_id, project, dimension, value, day)" : "(user_id, dimension, value, day)"
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS #{name}
      (
          user_id UInt32 CODEC(T64, ZSTD(1)),
          #{project_column}
          dimension LowCardinality(String) CODEC(ZSTD(1)),
          value String CODEC(ZSTD(3)),
          day Date CODEC(Delta(2), ZSTD(1)),
          seconds Float64 CODEC(Gorilla, ZSTD(1)),
          first_seconds Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1)),
          heartbeat_count Int64 CODEC(T64, ZSTD(1))
      )
      ENGINE = SummingMergeTree
      PARTITION BY toYYYYMM(day)
      PRIMARY KEY #{order_by}
      ORDER BY #{order_by}
      SETTINGS index_granularity = 8192
    SQL
  end
end
