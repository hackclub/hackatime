class CreateHeartbeatProjectDimensionDailyStats < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TABLE heartbeat_project_dimension_daily_stats
      (
          user_id UInt32 CODEC(T64, ZSTD(1)),
          project LowCardinality(String) CODEC(ZSTD(1)),
          dimension LowCardinality(String) CODEC(ZSTD(1)),
          value String CODEC(ZSTD(3)),
          day Date CODEC(Delta(2), ZSTD(1)),
          seconds Int64 CODEC(T64, ZSTD(1)),
          heartbeat_count Int64 CODEC(T64, ZSTD(1))
      )
      ENGINE = SummingMergeTree
      PARTITION BY toYYYYMM(day)
      PRIMARY KEY (user_id, project, dimension, value, day)
      ORDER BY (user_id, project, dimension, value, day)
      SETTINGS index_granularity = 8192
    SQL

    create_project_dimension_view("language", "language_seconds_delta")
    create_project_dimension_view("editor", "editor_seconds_delta")
    create_project_dimension_view("operating_system", "operating_system_seconds_delta")
    create_project_dimension_view("category", "category_seconds_delta")
    create_project_dimension_view("entity", "entity_seconds_delta")
    create_project_dimension_view("branch", "branch_seconds_delta")
  end

  def down
    %w[
      mv_heartbeat_project_branch_daily_stats
      mv_heartbeat_project_entity_daily_stats
      mv_heartbeat_project_category_daily_stats
      mv_heartbeat_project_operating_system_daily_stats
      mv_heartbeat_project_editor_daily_stats
      mv_heartbeat_project_language_daily_stats
      heartbeat_project_dimension_daily_stats
    ].each do |table_name|
      execute "DROP TABLE IF EXISTS #{table_name}"
    end
  end

  private

  def create_project_dimension_view(dimension, seconds_column)
    view_name = "mv_heartbeat_project_#{dimension}_daily_stats"
    execute <<~SQL
      CREATE MATERIALIZED VIEW #{view_name}
      TO heartbeat_project_dimension_daily_stats
      AS
      SELECT user_id,
             project,
             '#{dimension}' AS dimension,
             #{dimension} AS value,
             day,
             sum(#{seconds_column}) AS seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE project != '' AND #{dimension} != ''
      GROUP BY user_id, project, dimension, value, day
    SQL
  end
end
