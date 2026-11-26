class CreateStruggleWindows < ActiveRecord::Migration[8.1]
  def change
    create_table :struggle_windows do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :struggle_conversion, foreign_key: { on_delete: :nullify }
      t.string :project_hash, limit: 64, null: false
      t.string :project_name, limit: 128
      t.datetime :window_start, null: false
      t.integer :raw_seconds, limit: 2, null: false
      t.integer :convertible_seconds, limit: 2, null: false
      t.integer :credited_seconds, limit: 2, default: 0, null: false
      t.datetime :converted_at
      t.decimal :struggle_points, precision: 5, scale: 2, null: false
      t.decimal :diversity_multiplier, precision: 3, scale: 2, null: false
      t.decimal :verify_multiplier, precision: 3, scale: 2, default: 1.0, null: false
      t.decimal :effective_multiplier, precision: 4, scale: 3, null: false
      t.integer :effective_multiplier_milli, limit: 2, null: false
      t.integer :provenance_mask, limit: 2, default: 1, null: false
      t.string :primary_language, limit: 64
      t.string :ai_harness, limit: 64, default: "none", null: false
      t.jsonb :signal_counts, default: {}, null: false
      t.string :git_head_sha, limit: 40
      t.string :prev_chain_hash, limit: 64, null: false
      t.string :server_nonce, limit: 32, null: false
      t.string :chain_hash, limit: 64, null: false
      t.binary :signature, null: false

      t.timestamps
    end

    add_index :struggle_windows,
      [ :user_id, :project_hash, :window_start ],
      unique: true,
      name: "idx_struggle_windows_user_project_window"

    add_index :struggle_windows,
      [ :user_id, :window_start ],
      name: "idx_struggle_windows_user_time"

    add_index :struggle_windows,
      [ :user_id, :project_hash ],
      where: "converted_at IS NULL",
      name: "idx_struggle_windows_unconverted"

    add_check_constraint :struggle_windows,
      "raw_seconds BETWEEN 0 AND 300",
      name: "chk_struggle_windows_raw_seconds"

    add_check_constraint :struggle_windows,
      "convertible_seconds >= 0 AND convertible_seconds <= raw_seconds",
      name: "chk_struggle_windows_convertible_seconds"

    add_check_constraint :struggle_windows,
      "credited_seconds >= 0 AND credited_seconds <= convertible_seconds",
      name: "chk_struggle_windows_credited_seconds"

    add_check_constraint :struggle_windows,
      "struggle_points >= 0",
      name: "chk_struggle_windows_struggle_points"

    add_check_constraint :struggle_windows,
      "struggle_points >= 2.0 OR (convertible_seconds = 0 AND effective_multiplier = 0 AND effective_multiplier_milli = 0)",
      name: "chk_struggle_windows_min_sp_threshold"

    add_check_constraint :struggle_windows,
      "convertible_seconds <= LEAST(raw_seconds, CEIL(raw_seconds * LEAST(struggle_points / 10.0, 1.0)))",
      name: "chk_struggle_windows_sp_cap"
  end
end
