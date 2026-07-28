class AddUniqueActiveImportConstraintToHeartbeatImportRuns < ActiveRecord::Migration[8.1]
  def change
    # Partial unique index to enforce only one active import per user
    # This prevents race conditions in ensure_no_active_import!
    add_index :heartbeat_import_runs,
              :user_id,
              unique: true,
              where: "state IN (0, 1, 2, 3, 4)", # queued, requesting_dump, waiting_for_dump, downloading_dump, importing
              name: "index_heartbeat_import_runs_on_user_id_active"
  end
end
