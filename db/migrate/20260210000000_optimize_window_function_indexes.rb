class OptimizeWindowFunctionIndexes < ActiveRecord::Migration[8.1]
  def change
    # Add index optimized for PARTITION BY language ORDER BY time window functions
    # This supports queries grouping by language that need efficient time ordering within each language
    add_index :heartbeats, [ :user_id, :language, :time ],
              name: "idx_heartbeats_user_language_time_window",
              where: "deleted_at IS NULL AND language IS NOT NULL",
              if_not_exists: true

    # Add index optimized for PARTITION BY project ORDER BY time window functions
    # Note: We already have idx_heartbeats_user_project_time_stats which is (user_id, project, time)
    # This is already optimal for PARTITION BY project ORDER BY time when filtered by user_id
  end
end