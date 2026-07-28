class AddStatsPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :heartbeats, [ :user_id, :time, :project ],
              name: "idx_heartbeats_user_time_project_stats",
              where: "deleted_at IS NULL"

    add_index :heartbeats, [ :user_id, :time, :language ],
              name: "idx_heartbeats_user_time_language_stats",
              where: "deleted_at IS NULL"

    add_index :heartbeats, [ :user_id, :project, :time ],
              name: "idx_heartbeats_user_project_time_stats",
              where: "deleted_at IS NULL AND project IS NOT NULL"
  end
end
