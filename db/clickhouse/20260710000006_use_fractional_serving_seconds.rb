class UseFractionalServingSeconds < ActiveRecord::Migration[8.1]
  DELTA_SECONDS_COLUMNS = %w[
    user_seconds_delta user_first_seconds_delta
    project_seconds_delta project_first_seconds_delta
    language_seconds_delta language_first_seconds_delta
    editor_seconds_delta editor_first_seconds_delta
    operating_system_seconds_delta operating_system_first_seconds_delta
    machine_seconds_delta machine_first_seconds_delta
    category_seconds_delta category_first_seconds_delta
    entity_seconds_delta entity_first_seconds_delta
    branch_seconds_delta branch_first_seconds_delta
  ].freeze

  DAILY_TABLES = %w[
    heartbeat_user_daily_stats heartbeat_project_daily_stats
    heartbeat_dimension_daily_stats heartbeat_dimension_attribution_daily_stats
    heartbeat_project_dimension_daily_stats
  ].freeze

  def up
    DELTA_SECONDS_COLUMNS.each do |column|
      execute "ALTER TABLE heartbeat_interval_deltas MODIFY COLUMN #{column} Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1))"
    end
    DAILY_TABLES.each do |table|
      execute "ALTER TABLE #{table} MODIFY COLUMN seconds Float64 CODEC(Gorilla, ZSTD(1))"
      execute "ALTER TABLE #{table} MODIFY COLUMN first_seconds Float64 DEFAULT 0 CODEC(Gorilla, ZSTD(1))"
    end
    execute "ALTER TABLE heartbeat_project_summaries MODIFY COLUMN seconds Float64 CODEC(Gorilla, ZSTD(1))"
  end

  def down
    DELTA_SECONDS_COLUMNS.each do |column|
      execute "ALTER TABLE heartbeat_interval_deltas MODIFY COLUMN #{column} Int64 DEFAULT 0 CODEC(T64, ZSTD(1))"
    end
    DAILY_TABLES.each do |table|
      execute "ALTER TABLE #{table} MODIFY COLUMN seconds Int64 CODEC(T64, ZSTD(1))"
      execute "ALTER TABLE #{table} MODIFY COLUMN first_seconds Int64 DEFAULT 0 CODEC(T64, ZSTD(1))"
    end
    execute "ALTER TABLE heartbeat_project_summaries MODIFY COLUMN seconds Int64 CODEC(T64, ZSTD(1))"
  end
end
