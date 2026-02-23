class CreateHeartbeatImportSources < ActiveRecord::Migration[8.1]
  def change
    create_table :heartbeat_import_sources do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :provider, null: false, default: 0
      t.string :endpoint_url, null: false
      t.string :encrypted_api_key, null: false
      t.boolean :sync_enabled, null: false, default: true
      t.integer :status, null: false, default: 0
      t.date :initial_backfill_start_date
      t.date :initial_backfill_end_date
      t.date :backfill_cursor_date
      t.datetime :last_synced_at
      t.text :last_error_message
      t.datetime :last_error_at
      t.integer :consecutive_failures, null: false, default: 0

      t.timestamps
    end
  end
end
