class IncludeBlankProjectEntities < ActiveRecord::Migration[8.1]
  NULL_VALUE = "__HACKATIME_NULL_DIMENSION_7F3D8C2A__".freeze

  def up
    replace_view(include_blank: true)
    execute <<~SQL
      INSERT INTO heartbeat_project_dimension_daily_stats
      SELECT user_id,
             project,
             'entity' AS dimension,
             entity AS value,
             day,
             sum(project_seconds_delta) AS seconds,
             sum(project_first_seconds_delta) AS first_seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE project != '' AND entity = ''
      GROUP BY user_id, project, dimension, value, day
    SQL
  end

  def down
    replace_view(include_blank: false)
    execute <<~SQL
      INSERT INTO heartbeat_project_dimension_daily_stats
      SELECT user_id,
             project,
             dimension,
             value,
             day,
             -sum(seconds) AS seconds,
             -sum(first_seconds) AS first_seconds,
             -sum(heartbeat_count) AS heartbeat_count
      FROM heartbeat_project_dimension_daily_stats
      WHERE dimension = 'entity' AND value = ''
      GROUP BY user_id, project, dimension, value, day
    SQL
  end

  private

  def replace_view(include_blank:)
    execute "DROP TABLE IF EXISTS mv_heartbeat_project_entity_daily_stats"
    entity_condition = include_blank ? "entity != '#{NULL_VALUE}'" : "entity NOT IN ('', '#{NULL_VALUE}')"
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_project_entity_daily_stats
      TO heartbeat_project_dimension_daily_stats
      AS
      SELECT user_id,
             project,
             'entity' AS dimension,
             entity AS value,
             day,
             sum(project_seconds_delta) AS seconds,
             sum(project_first_seconds_delta) AS first_seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE project != '' AND #{entity_condition}
      GROUP BY user_id, project, dimension, value, day
    SQL
  end
end
