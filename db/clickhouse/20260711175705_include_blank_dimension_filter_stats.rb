class IncludeBlankDimensionFilterStats < ActiveRecord::Migration[8.1]
  DIMENSIONS = %w[language editor operating_system machine category entity branch].freeze

  def up
    DIMENSIONS.each do |dimension|
      replace_view(dimension, include_blank: true)
      backfill_blank_rows(dimension)
    end
  end

  def down
    DIMENSIONS.each do |dimension|
      replace_view(dimension, include_blank: false)
    end
  end

  private

  def replace_view(dimension, include_blank:)
    execute "DROP TABLE IF EXISTS mv_heartbeat_#{dimension}_daily_stats"
    condition = "WHERE #{dimension} != ''" unless include_blank
    execute <<~SQL
      CREATE MATERIALIZED VIEW mv_heartbeat_#{dimension}_daily_stats
      TO heartbeat_dimension_daily_stats
      AS
      SELECT user_id,
             '#{dimension}' AS dimension,
             #{dimension} AS value,
             day,
             sum(#{dimension}_seconds_delta) AS seconds,
             sum(#{dimension}_first_seconds_delta) AS first_seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      #{condition}
      GROUP BY user_id, dimension, value, day
    SQL
  end

  def backfill_blank_rows(dimension)
    execute <<~SQL
      INSERT INTO heartbeat_dimension_daily_stats
      SELECT user_id,
             '#{dimension}' AS dimension,
             '' AS value,
             day,
             sum(#{dimension}_seconds_delta) AS seconds,
             sum(#{dimension}_first_seconds_delta) AS first_seconds,
             sum(heartbeat_count_delta) AS heartbeat_count
      FROM heartbeat_interval_deltas
      WHERE #{dimension} = ''
      GROUP BY user_id, dimension, value, day
    SQL
  end
end
