class CreateHeartbeatExclusions < ActiveRecord::Migration[8.1]
  def change
    create_table :heartbeat_exclusions do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.integer :kind, null: false
      t.string :project
      t.datetime :starts_at
      t.datetime :ends_at
      t.text :reason
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :revoked_at
      t.references :revoked_by, foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end

    add_index :heartbeat_exclusions, :user_id, where: "revoked_at IS NULL",
      name: "index_heartbeat_exclusions_active_on_user_id"
    add_index :heartbeat_exclusions, [ :user_id, :created_at ]
    # A user has at most one active poison (kind 0).
    add_index :heartbeat_exclusions, :user_id, unique: true, where: "kind = 0 AND revoked_at IS NULL",
      name: "index_heartbeat_exclusions_one_active_poison_per_user"

    add_check_constraint :heartbeat_exclusions, "starts_at IS NULL OR ends_at IS NULL OR starts_at < ends_at",
      name: "heartbeat_exclusions_range_order"
    add_check_constraint :heartbeat_exclusions, "kind <> 0 OR (ends_at IS NOT NULL AND project IS NULL)",
      name: "heartbeat_exclusions_poison_shape"
    add_check_constraint :heartbeat_exclusions, "kind <> 1 OR project IS NOT NULL",
      name: "heartbeat_exclusions_project_deletion_shape"
  end
end
