class IncludeProjectInHeartbeatsUserTimeIdIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # The heartbeat_exclusions default scope compares heartbeats.project. Without
  # project in this index, per-user duration reads lose their index-only scans.
  def change
    add_index :heartbeats, [ :user_id, :time, :id ],
      name: :idx_heartbeats_user_time_id_project_active,
      where: "deleted_at IS NULL",
      include: [ :project ],
      algorithm: :concurrently,
      if_not_exists: true

    remove_index :heartbeats, [ :user_id, :time, :id ],
      name: :idx_heartbeats_user_time_id_active,
      where: "deleted_at IS NULL",
      algorithm: :concurrently,
      if_exists: true
  end
end
