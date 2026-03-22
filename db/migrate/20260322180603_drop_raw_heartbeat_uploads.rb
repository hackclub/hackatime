class DropRawHeartbeatUploads < ActiveRecord::Migration[8.1]
  def up
    if foreign_key_exists?(:heartbeats, :raw_heartbeat_uploads)
      remove_foreign_key :heartbeats, :raw_heartbeat_uploads
    end
    if index_exists?(:heartbeats, :raw_heartbeat_upload_id)
      remove_index :heartbeats, :raw_heartbeat_upload_id
    end
    if column_exists?(:heartbeats, :raw_heartbeat_upload_id)
      remove_column :heartbeats, :raw_heartbeat_upload_id
    end
    drop_table :raw_heartbeat_uploads, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
