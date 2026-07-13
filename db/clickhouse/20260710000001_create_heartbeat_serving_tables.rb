class CreateHeartbeatServingTables < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TABLE heartbeat_interval_deltas
      (
          delta_id UInt64 CODEC(Delta(8), LZ4),
          user_id UInt32 CODEC(T64, ZSTD(1)),
          day Date CODEC(Delta(2), ZSTD(1)),
          time Float64 CODEC(Gorilla, ZSTD(1)),
          project LowCardinality(String) CODEC(ZSTD(1)),
          language LowCardinality(String) CODEC(ZSTD(1)),
          editor LowCardinality(String) CODEC(ZSTD(1)),
          operating_system LowCardinality(String) CODEC(ZSTD(1)),
          category LowCardinality(String) CODEC(ZSTD(1)),
          entity String CODEC(ZSTD(3)),
          branch String CODEC(ZSTD(3)),
          user_seconds_delta Int64 CODEC(T64, ZSTD(1)),
          project_seconds_delta Int64 CODEC(T64, ZSTD(1)),
          language_seconds_delta Int64 CODEC(T64, ZSTD(1)),
          editor_seconds_delta Int64 CODEC(T64, ZSTD(1)),
          operating_system_seconds_delta Int64 CODEC(T64, ZSTD(1)),
          category_seconds_delta Int64 CODEC(T64, ZSTD(1)),
          entity_seconds_delta Int64 CODEC(T64, ZSTD(1)),
          branch_seconds_delta Int64 CODEC(T64, ZSTD(1)),
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

    execute <<~SQL
      CREATE TABLE heartbeat_user_daily_stats
      (
          user_id UInt32 CODEC(T64, ZSTD(1)),
          day Date CODEC(Delta(2), ZSTD(1)),
          seconds Int64 CODEC(T64, ZSTD(1)),
          heartbeat_count Int64 CODEC(T64, ZSTD(1))
      )
      ENGINE = SummingMergeTree
      PARTITION BY toYYYYMM(day)
      PRIMARY KEY (user_id, day)
      ORDER BY (user_id, day)
      SETTINGS index_granularity = 8192
    SQL

    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_user_daily_stats
      TO heartbeat_user_daily_stats
      AS
      SELECT user_id,
             day,
             sum(user_seconds_delta) AS seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      GROUP BY user_id, day
    SQL

    execute <<~SQL
      CREATE TABLE heartbeat_project_daily_stats
      (
          user_id UInt32 CODEC(T64, ZSTD(1)),
          project LowCardinality(String) CODEC(ZSTD(1)),
          day Date CODEC(Delta(2), ZSTD(1)),
          seconds Int64 CODEC(T64, ZSTD(1)),
          heartbeat_count Int64 CODEC(T64, ZSTD(1))
      )
      ENGINE = SummingMergeTree
      PARTITION BY toYYYYMM(day)
      PRIMARY KEY (user_id, project, day)
      ORDER BY (user_id, project, day)
      SETTINGS index_granularity = 8192
    SQL

    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_project_daily_stats
      TO heartbeat_project_daily_stats
      AS
      SELECT user_id,
             project,
             day,
             sum(project_seconds_delta) AS seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE project != ''
      GROUP BY user_id, project, day
    SQL

    execute <<~SQL
      CREATE TABLE heartbeat_dimension_daily_stats
      (
          user_id UInt32 CODEC(T64, ZSTD(1)),
          dimension LowCardinality(String) CODEC(ZSTD(1)),
          value String CODEC(ZSTD(3)),
          day Date CODEC(Delta(2), ZSTD(1)),
          seconds Int64 CODEC(T64, ZSTD(1)),
          heartbeat_count Int64 CODEC(T64, ZSTD(1))
      )
      ENGINE = SummingMergeTree
      PARTITION BY toYYYYMM(day)
      PRIMARY KEY (user_id, dimension, value, day)
      ORDER BY (user_id, dimension, value, day)
      SETTINGS index_granularity = 8192
    SQL

    create_dimension_view("language", "language_seconds_delta")
    create_dimension_view("editor", "editor_seconds_delta")
    create_dimension_view("operating_system", "operating_system_seconds_delta")
    create_dimension_view("category", "category_seconds_delta")
    create_dimension_view("entity", "entity_seconds_delta")
    create_dimension_view("branch", "branch_seconds_delta")

    execute <<~SQL
      CREATE TABLE heartbeat_project_summaries
      (
          user_id UInt32 CODEC(T64, ZSTD(1)),
          project LowCardinality(String) CODEC(ZSTD(1)),
          seconds Int64 CODEC(T64, ZSTD(1)),
          heartbeat_count Int64 CODEC(T64, ZSTD(1))
      )
      ENGINE = SummingMergeTree
      PRIMARY KEY (user_id, project)
      ORDER BY (user_id, project)
      SETTINGS index_granularity = 8192
    SQL

    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_project_summaries
      TO heartbeat_project_summaries
      AS
      SELECT user_id,
             project,
             sum(project_seconds_delta) AS seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE project != ''
      GROUP BY user_id, project
    SQL
  end

  def down
    %w[
      mv_heartbeat_project_summaries
      heartbeat_project_summaries
      mv_heartbeat_branch_daily_stats
      mv_heartbeat_entity_daily_stats
      mv_heartbeat_category_daily_stats
      mv_heartbeat_operating_system_daily_stats
      mv_heartbeat_editor_daily_stats
      mv_heartbeat_language_daily_stats
      heartbeat_dimension_daily_stats
      mv_heartbeat_project_daily_stats
      heartbeat_project_daily_stats
      mv_heartbeat_user_daily_stats
      heartbeat_user_daily_stats
      heartbeat_interval_deltas
    ].each do |table_name|
      execute "DROP TABLE IF EXISTS #{table_name}"
    end
  end

  private

  def create_dimension_view(dimension, seconds_column)
    view_name = "mv_heartbeat_#{dimension}_daily_stats"
    execute <<~SQL
      CREATE MATERIALIZED VIEW #{view_name}
      TO heartbeat_dimension_daily_stats
      AS
      SELECT user_id,
             '#{dimension}' AS dimension,
             #{dimension} AS value,
             day,
             sum(#{seconds_column}) AS seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE #{dimension} != ''
      GROUP BY user_id, dimension, value, day
    SQL
  end
end
