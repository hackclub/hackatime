class CreateHeartbeatImportRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :heartbeat_import_runs do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :source_kind, null: false
      t.integer :state, null: false, default: 0
      t.string :source_filename
      t.string :encrypted_api_key
      t.string :remote_dump_id
      t.string :remote_dump_status
      t.float :remote_percent_complete
      t.integer :processed_count, null: false, default: 0
      t.integer :total_count
      t.integer :imported_count
      t.integer :skipped_count
      t.integer :errors_count, null: false, default: 0
      t.text :message
      t.text :error_message
      t.datetime :started_at
      t.datetime :finished_at
      t.datetime :remote_requested_at

      t.timestamps
    end

    add_index :heartbeat_import_runs, [ :user_id, :created_at ]
    add_index :heartbeat_import_runs, [ :user_id, :state ]
  end
end
