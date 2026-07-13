class SeparateDimensionAttributionStats < ActiveRecord::Migration[8.1]
  DIMENSIONS = %w[language editor operating_system machine category entity branch].freeze
  PROJECT_DIMENSIONS = %w[language editor operating_system category entity branch].freeze

  def up
    execute <<~SQL
      CREATE TABLE heartbeat_dimension_attribution_daily_stats
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

    DIMENSIONS.each { |dimension| backfill_attribution(dimension) }
    DIMENSIONS.each { |dimension| create_attribution_view(dimension) }

    PROJECT_DIMENSIONS.each do |dimension|
      execute "DROP TABLE IF EXISTS mv_heartbeat_project_#{dimension}_daily_stats"
    end
    execute "TRUNCATE TABLE heartbeat_project_dimension_daily_stats"
    PROJECT_DIMENSIONS.each { |dimension| backfill_project_attribution(dimension) }
    PROJECT_DIMENSIONS.each { |dimension| create_project_attribution_view(dimension) }
  end

  def down
    PROJECT_DIMENSIONS.each { |dimension| replace_project_filter_view(dimension) }
    DIMENSIONS.reverse_each do |dimension|
      execute "DROP TABLE IF EXISTS mv_heartbeat_#{dimension}_attribution_daily_stats"
    end
    execute "DROP TABLE IF EXISTS heartbeat_dimension_attribution_daily_stats"
  end

  private

  def create_attribution_view(dimension)
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_#{dimension}_attribution_daily_stats
      TO heartbeat_dimension_attribution_daily_stats
      AS
      SELECT user_id,
             '#{dimension}' AS dimension,
             #{dimension} AS value,
             day,
             sum(user_seconds_delta) AS seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE #{dimension} != ''
      GROUP BY user_id, dimension, value, day
    SQL
  end

  def backfill_attribution(dimension)
    execute <<~SQL
      INSERT INTO heartbeat_dimension_attribution_daily_stats
      SELECT user_id,
             '#{dimension}' AS dimension,
             #{dimension} AS value,
             day,
             sum(user_seconds_delta) AS seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE #{dimension} != ''
      GROUP BY user_id, dimension, value, day
    SQL
  end

  def backfill_project_attribution(dimension)
    execute <<~SQL
      INSERT INTO heartbeat_project_dimension_daily_stats
      SELECT user_id,
             project,
             '#{dimension}' AS dimension,
             #{dimension} AS value,
             day,
             sum(project_seconds_delta) AS seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE project != '' AND #{dimension} != ''
      GROUP BY user_id, project, dimension, value, day
    SQL
  end

  def create_project_attribution_view(dimension)
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_project_#{dimension}_daily_stats
      TO heartbeat_project_dimension_daily_stats
      AS
      SELECT user_id,
             project,
             '#{dimension}' AS dimension,
             #{dimension} AS value,
             day,
             sum(project_seconds_delta) AS seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE project != '' AND #{dimension} != ''
      GROUP BY user_id, project, dimension, value, day
    SQL
  end

  def replace_project_filter_view(dimension)
    execute "DROP TABLE IF EXISTS mv_heartbeat_project_#{dimension}_daily_stats"
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_project_#{dimension}_daily_stats
      TO heartbeat_project_dimension_daily_stats
      AS
      SELECT user_id,
             project,
             '#{dimension}' AS dimension,
             #{dimension} AS value,
             day,
             sum(#{dimension}_seconds_delta) AS seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE project != '' AND #{dimension} != ''
      GROUP BY user_id, project, dimension, value, day
    SQL
  end
end
