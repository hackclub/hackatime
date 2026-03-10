class DropHeartbeatImportSources < ActiveRecord::Migration[8.0]
  def up
    drop_table :heartbeat_import_sources, if_exists: true
  end

  def down
    create_table :heartbeat_import_sources do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false, default: "wakatime"
      t.string :endpoint_url, null: false
      t.text :encrypted_api_key
      t.boolean :sync_enabled, null: false, default: true
      t.string :status, null: false, default: "pending"
      t.datetime :last_synced_at
      t.text :last_error_message
      t.datetime :last_error_at
      t.integer :consecutive_failures, null: false, default: 0
      t.timestamps
    end
  end
end
