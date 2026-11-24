class CreateStrugglePointEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :struggle_windows, :persisted_diff_lines, :integer, null: false, default: 0
    add_column :struggle_windows, :anomaly_flags, :jsonb, null: false, default: []

    add_column :audit_submissions, :sampled_randomly, :boolean, null: false, default: false
    add_column :audit_submissions, :sampling_reason, :string

    create_table :struggle_point_events do |t|
      t.references :struggle_window, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :project_hash, null: false
      t.string :project_name
      t.datetime :window_start, null: false
      t.string :signal_code, null: false
      t.integer :trigger_count, null: false, default: 1
      t.decimal :raw_points, precision: 6, scale: 2, null: false, default: 0.0
      t.decimal :awarded_points, precision: 6, scale: 2, null: false, default: 0.0
      t.string :provenance_tier, null: false, default: "tier_b"
      t.integer :persisted_diff_lines, null: false, default: 0
      t.string :git_head_sha
      t.string :gate_status, null: false, default: "awarded"

      t.timestamps
    end

    add_index :struggle_point_events, [ :struggle_window_id, :signal_code ],
      unique: true,
      name: "idx_sp_events_window_signal"
    add_index :struggle_point_events, [ :user_id, :window_start ],
      name: "idx_sp_events_user_time"
    add_index :struggle_point_events, [ :user_id, :project_hash, :signal_code ],
      name: "idx_sp_events_user_project_signal"
    add_index :struggle_point_events, [ :gate_status, :created_at ],
      name: "idx_sp_events_gate_status"
  end
end
