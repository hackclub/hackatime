class AddHeartbeatSummaryAggregationIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :heartbeats, [ :user_id, :time, :id ],
      name: :idx_heartbeats_user_time_id_active,
      where: "deleted_at IS NULL",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :heartbeats, [ :user_id, :language, :time, :id ],
      name: :idx_heartbeats_user_language_time_id_active,
      where: "deleted_at IS NULL",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :heartbeats, [ :user_id, :project, :time, :id ],
      name: :idx_heartbeats_user_project_time_id_language_active,
      where: "deleted_at IS NULL AND project IS NOT NULL",
      include: [ :language ],
      algorithm: :concurrently,
      if_not_exists: true
  end
end
