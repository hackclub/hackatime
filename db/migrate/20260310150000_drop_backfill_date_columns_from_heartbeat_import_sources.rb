class DropBackfillDateColumnsFromHeartbeatImportSources < ActiveRecord::Migration[8.0]
  def change
    remove_column :heartbeat_import_sources, :initial_backfill_start_date, :date
    remove_column :heartbeat_import_sources, :initial_backfill_end_date, :date
  end
end
