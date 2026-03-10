class DropWakatimeMirrors < ActiveRecord::Migration[8.1]
  def up
    drop_table :wakatime_mirrors, if_exists: true

    remove_index :heartbeats,
      name: "index_heartbeats_on_user_source_id_direct",
      if_exists: true
  end

  def down
    create_table :wakatime_mirrors do |t|
      t.references :user, null: false, foreign_key: true
      t.string :endpoint_url, null: false
      t.string :encrypted_api_key
      t.datetime :last_synced_at
      t.string :status, default: "active"
      t.text :last_error_message
      t.datetime :last_error_at
      t.integer :consecutive_failures, default: 0
      t.bigint :sync_cursor
      t.string :sync_state, default: "idle"
      t.timestamps
    end

    add_index :wakatime_mirrors, [ :user_id, :endpoint_url ], unique: true

    add_index :heartbeats,
      [ :user_id, :source_type, :id ],
      name: "index_heartbeats_on_user_source_id_direct",
      where: "(source_type = 0 AND deleted_at IS NULL)"
  end
end
