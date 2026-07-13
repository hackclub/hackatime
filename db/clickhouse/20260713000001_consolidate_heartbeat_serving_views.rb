class ConsolidateHeartbeatServingViews < ActiveRecord::Migration[8.1]
  NULL_VALUE = "__HACKATIME_NULL_DIMENSION_7F3D8C2A__".freeze
  FILTER_DIMENSIONS = %w[language editor operating_system machine category entity branch].freeze
  PROJECT_DIMENSIONS = FILTER_DIMENSIONS.without("machine").freeze

  def up
    drop_serving_views
    create_user_view
    create_project_views
    create_filter_view
    create_attribution_view
    create_project_dimension_view
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The superseded per-dimension materialized views are intentionally not restored"
  end

  private

  def drop_serving_views
    names = connection.select_values(<<~SQL.squish)
      SELECT name
      FROM system.tables
      WHERE database = currentDatabase()
        AND engine = 'MaterializedView'
        AND name LIKE 'mv_heartbeat_%'
    SQL
    names.each { |name| execute "DROP TABLE IF EXISTS #{connection.quote_table_name(name)}" }
  end

  def create_user_view
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_user_daily_stats
      TO heartbeat_user_daily_stats
      AS
      SELECT user_id,
             day,
             sum(user_seconds_delta) AS seconds,
             sum(user_first_seconds_delta) AS first_seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      GROUP BY user_id, day
    SQL
  end

  def create_project_views
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_project_daily_stats
      TO heartbeat_project_daily_stats
      AS
      SELECT user_id,
             project,
             day,
             sum(project_seconds_delta) AS seconds,
             sum(project_first_seconds_delta) AS first_seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      GROUP BY user_id, project, day
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
      GROUP BY user_id, project
    SQL
  end

  def create_filter_view
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_dimension_daily_stats
      TO heartbeat_dimension_daily_stats
      AS
      SELECT user_id,
             dimension_value.1 AS dimension,
             dimension_value.2 AS value,
             day,
             sum(dimension_value.3) AS seconds,
             sum(dimension_value.4) AS first_seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      ARRAY JOIN [#{filter_dimension_tuples}] AS dimension_value
      GROUP BY user_id, dimension, value, day
    SQL
  end

  def create_attribution_view
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_dimension_attribution_daily_stats
      TO heartbeat_dimension_attribution_daily_stats
      AS
      SELECT user_id,
             dimension_value.1 AS dimension,
             dimension_value.2 AS value,
             day,
             sum(user_seconds_delta) AS seconds,
             sum(user_first_seconds_delta) AS first_seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      ARRAY JOIN [#{dimension_value_tuples(FILTER_DIMENSIONS)}] AS dimension_value
      WHERE value NOT IN ('', '#{NULL_VALUE}')
      GROUP BY user_id, dimension, value, day
    SQL
  end

  def create_project_dimension_view
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_project_dimension_daily_stats
      TO heartbeat_project_dimension_daily_stats
      AS
      SELECT user_id,
             project,
             dimension_value.1 AS dimension,
             dimension_value.2 AS value,
             day,
             sum(project_seconds_delta) AS seconds,
             sum(project_first_seconds_delta) AS first_seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      ARRAY JOIN [#{dimension_value_tuples(PROJECT_DIMENSIONS)}] AS dimension_value
      WHERE project != ''
        AND value != '#{NULL_VALUE}'
        AND (dimension = 'entity' OR value != '')
      GROUP BY user_id, project, dimension, value, day
    SQL
  end

  def filter_dimension_tuples
    FILTER_DIMENSIONS.map do |dimension|
      "('#{dimension}', #{dimension}, #{dimension}_seconds_delta, #{dimension}_first_seconds_delta)"
    end.join(", ")
  end

  def dimension_value_tuples(dimensions)
    dimensions.map { |dimension| "('#{dimension}', #{dimension})" }.join(", ")
  end
end
