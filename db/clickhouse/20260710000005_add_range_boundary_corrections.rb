class AddRangeBoundaryCorrections < ActiveRecord::Migration[8.1]
  DIMENSIONS = %w[project language editor operating_system machine category entity branch].freeze
  FILTER_DIMENSIONS = DIMENSIONS.without("project").freeze
  PROJECT_DIMENSIONS = %w[language editor operating_system category entity branch].freeze

  def up
    add_delta_columns
    add_serving_columns
    replace_views
  end

  def down
    drop_views
    remove_serving_columns
    remove_delta_columns
    restore_views
  end

  private

  def add_delta_columns
    execute <<~SQL
      ALTER TABLE heartbeat_interval_deltas
      ADD COLUMN user_first_seconds_delta Int64 DEFAULT 0 CODEC(T64, ZSTD(1)) AFTER user_seconds_delta
    SQL
    DIMENSIONS.each do |dimension|
      execute <<~SQL
        ALTER TABLE heartbeat_interval_deltas
        ADD COLUMN #{dimension}_first_seconds_delta Int64 DEFAULT 0 CODEC(T64, ZSTD(1)) AFTER #{dimension}_seconds_delta
      SQL
    end
  end

  def add_serving_columns
    %w[
      heartbeat_user_daily_stats heartbeat_project_daily_stats
      heartbeat_dimension_daily_stats heartbeat_dimension_attribution_daily_stats
      heartbeat_project_dimension_daily_stats
    ].each do |table|
      execute <<~SQL
        ALTER TABLE #{table}
        ADD COLUMN first_seconds Int64 DEFAULT 0 CODEC(T64, ZSTD(1)) AFTER seconds
      SQL
    end
  end

  def replace_views
    drop_views
    create_user_view(first_column: "user_first_seconds_delta")
    create_project_view(first_column: "project_first_seconds_delta")
    FILTER_DIMENSIONS.each do |dimension|
      create_filter_view(dimension, first_column: "#{dimension}_first_seconds_delta")
      create_attribution_view(dimension, first_column: "user_first_seconds_delta")
    end
    PROJECT_DIMENSIONS.each do |dimension|
      create_project_attribution_view(dimension, first_column: "project_first_seconds_delta")
    end
  end

  def restore_views
    create_user_view
    create_project_view
    FILTER_DIMENSIONS.each do |dimension|
      create_filter_view(dimension)
      create_attribution_view(dimension)
    end
    PROJECT_DIMENSIONS.each { |dimension| create_project_attribution_view(dimension) }
  end

  def drop_views
    view_names.each { |view| execute "DROP TABLE IF EXISTS #{view}" }
  end

  def view_names
    %w[mv_heartbeat_user_daily_stats mv_heartbeat_project_daily_stats] +
      FILTER_DIMENSIONS.flat_map do |dimension|
        [ "mv_heartbeat_#{dimension}_daily_stats", "mv_heartbeat_#{dimension}_attribution_daily_stats" ]
      end +
      PROJECT_DIMENSIONS.map { |dimension| "mv_heartbeat_project_#{dimension}_daily_stats" }
  end

  def create_user_view(first_column: nil)
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_user_daily_stats
      TO heartbeat_user_daily_stats
      AS
      SELECT user_id,
             day,
             sum(user_seconds_delta) AS seconds,
             #{first_select(first_column)}
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      GROUP BY user_id, day
    SQL
  end

  def create_project_view(first_column: nil)
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_project_daily_stats
      TO heartbeat_project_daily_stats
      AS
      SELECT user_id,
             project,
             day,
             sum(project_seconds_delta) AS seconds,
             #{first_select(first_column)}
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE project != ''
      GROUP BY user_id, project, day
    SQL
  end

  def create_filter_view(dimension, first_column: nil)
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_#{dimension}_daily_stats
      TO heartbeat_dimension_daily_stats
      AS
      SELECT user_id,
             '#{dimension}' AS dimension,
             #{dimension} AS value,
             day,
             sum(#{dimension}_seconds_delta) AS seconds,
             #{first_select(first_column)}
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE #{dimension} != ''
      GROUP BY user_id, dimension, value, day
    SQL
  end

  def create_attribution_view(dimension, first_column: nil)
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_#{dimension}_attribution_daily_stats
      TO heartbeat_dimension_attribution_daily_stats
      AS
      SELECT user_id,
             '#{dimension}' AS dimension,
             #{dimension} AS value,
             day,
             sum(user_seconds_delta) AS seconds,
             #{first_select(first_column)}
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE #{dimension} != ''
      GROUP BY user_id, dimension, value, day
    SQL
  end

  def create_project_attribution_view(dimension, first_column: nil)
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
             #{first_select(first_column)}
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE project != '' AND #{dimension} != ''
      GROUP BY user_id, project, dimension, value, day
    SQL
  end

  def first_select(column)
    column ? "sum(#{column}) AS first_seconds," : ""
  end

  def remove_serving_columns
    %w[
      heartbeat_user_daily_stats heartbeat_project_daily_stats
      heartbeat_dimension_daily_stats heartbeat_dimension_attribution_daily_stats
      heartbeat_project_dimension_daily_stats
    ].each { |table| execute "ALTER TABLE #{table} DROP COLUMN IF EXISTS first_seconds" }
  end

  def remove_delta_columns
    execute "ALTER TABLE heartbeat_interval_deltas DROP COLUMN IF EXISTS user_first_seconds_delta"
    DIMENSIONS.each do |dimension|
      execute "ALTER TABLE heartbeat_interval_deltas DROP COLUMN IF EXISTS #{dimension}_first_seconds_delta"
    end
  end
end
