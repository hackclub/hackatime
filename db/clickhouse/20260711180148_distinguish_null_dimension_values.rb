class DistinguishNullDimensionValues < ActiveRecord::Migration[8.1]
  NULL_VALUE = "__HACKATIME_NULL_DIMENSION_7F3D8C2A__".freeze
  DIMENSIONS = %w[language editor operating_system machine category entity branch].freeze
  PROJECT_DIMENSIONS = %w[language editor operating_system category entity branch].freeze

  def up
    DIMENSIONS.each { |dimension| replace_attribution_view(dimension, exclude_null: true) }
    PROJECT_DIMENSIONS.each { |dimension| replace_project_attribution_view(dimension, exclude_null: true) }
  end

  def down
    DIMENSIONS.each { |dimension| replace_attribution_view(dimension, exclude_null: false) }
    PROJECT_DIMENSIONS.each { |dimension| replace_project_attribution_view(dimension, exclude_null: false) }
  end

  private

  def replace_attribution_view(dimension, exclude_null:)
    execute "DROP TABLE IF EXISTS mv_heartbeat_#{dimension}_attribution_daily_stats"
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_#{dimension}_attribution_daily_stats
      TO heartbeat_dimension_attribution_daily_stats
      AS
      SELECT user_id,
             '#{dimension}' AS dimension,
             #{dimension} AS value,
             day,
             sum(user_seconds_delta) AS seconds,
             sum(user_first_seconds_delta) AS first_seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE #{present_condition(dimension, exclude_null:)}
      GROUP BY user_id, dimension, value, day
    SQL
  end

  def replace_project_attribution_view(dimension, exclude_null:)
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
             sum(project_seconds_delta) AS seconds,
             sum(project_first_seconds_delta) AS first_seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE project != '' AND #{present_condition(dimension, exclude_null:)}
      GROUP BY user_id, project, dimension, value, day
    SQL
  end

  def present_condition(dimension, exclude_null:)
    return "#{dimension} != ''" unless exclude_null

    "#{dimension} NOT IN ('', '#{NULL_VALUE}')"
  end
end
