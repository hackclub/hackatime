class CreateHeartbeatRemappingTables < ActiveRecord::Migration[8.1]
  def change
    create_table :heartbeat_hash_aliases do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :heartbeat_id, null: false
      t.text :alias_hash, null: false
      t.text :canonical_hash, null: false

      t.timestamps
    end
    add_index :heartbeat_hash_aliases, [ :user_id, :alias_hash ], unique: true
    add_index :heartbeat_hash_aliases, :heartbeat_id

    create_table :heartbeat_remap_runs do |t|
      t.boolean :dry_run, null: false, default: true
      t.integer :state, null: false, default: 0
      t.integer :batch_size, null: false
      t.bigint :cursor_id, null: false, default: 0
      t.bigint :max_heartbeat_id, null: false
      t.bigint :scanned_count, null: false, default: 0
      t.bigint :changed_count, null: false, default: 0
      t.bigint :deduplicated_count, null: false, default: 0
      t.bigint :stale_count, null: false, default: 0
      t.bigint :unsafe_count, null: false, default: 0
      t.bigint :error_count, null: false, default: 0
      t.string :rule_ids, array: true, null: false, default: []
      t.text :error_message
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    create_table :heartbeat_remap_changes do |t|
      t.references :heartbeat_remap_run, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :heartbeat_id, null: false
      t.bigint :winner_heartbeat_id
      t.string :action, null: false
      t.string :rule_ids, array: true, null: false, default: []
      t.jsonb :preimage, null: false, default: {}
      t.jsonb :postimage, null: false, default: {}
      t.datetime :rolled_back_at

      t.timestamps
    end
    add_index :heartbeat_remap_changes,
      [ :heartbeat_remap_run_id, :heartbeat_id ],
      unique: true,
      name: :index_heartbeat_remap_changes_on_run_and_heartbeat
    add_index :heartbeat_remap_changes,
      [ :heartbeat_remap_run_id, :rolled_back_at, :action, :id ],
      name: :index_heartbeat_remap_changes_on_pending_rollback

    create_table :heartbeat_remap_alias_changes do |t|
      t.references :heartbeat_remap_run, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: true
      t.bigint :heartbeat_id, null: false
      t.text :alias_hash, null: false
      t.bigint :before_heartbeat_id
      t.text :before_canonical_hash
      t.bigint :after_heartbeat_id, null: false
      t.text :after_canonical_hash, null: false
      t.datetime :rolled_back_at

      t.timestamps
    end
    add_index :heartbeat_remap_alias_changes,
      [ :heartbeat_remap_run_id, :user_id, :alias_hash ],
      unique: true,
      name: :index_heartbeat_remap_alias_changes_on_run_user_alias
    add_index :heartbeat_remap_alias_changes,
      [ :heartbeat_remap_run_id, :heartbeat_id, :rolled_back_at ],
      name: :index_heartbeat_remap_alias_changes_on_rollback_owner
  end
end
