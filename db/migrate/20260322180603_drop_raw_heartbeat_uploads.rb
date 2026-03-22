class DropRawHeartbeatUploads < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :heartbeats, :raw_heartbeat_uploads
    remove_index :heartbeats, :raw_heartbeat_upload_id
    remove_column :heartbeats, :raw_heartbeat_upload_id, :bigint
    drop_table :raw_heartbeat_uploads do |t|
      t.text :body
      t.bigint :user_id
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index :user_id
    end
  end
end
