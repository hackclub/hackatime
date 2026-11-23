class CreateAuditSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_submissions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :project_hash, limit: 64, null: false
      t.string :project_name, limit: 128
      t.string :program_slug, limit: 64, null: false
      t.string :git_remote_url
      t.string :bundle_sha256, limit: 64, null: false
      t.decimal :submitted_hours, precision: 8, scale: 2, null: false
      t.decimal :approved_hours, precision: 8, scale: 2
      t.boolean :chain_verified, default: false, null: false
      t.boolean :git_push_verified, default: false, null: false
      t.decimal :plugin_share_pct, precision: 5, scale: 2, default: 0.0, null: false
      t.jsonb :anomaly_flags, default: [], null: false
      t.string :review_status, limit: 32, default: "pending", null: false
      t.text :reviewer_notes
      t.bigint :reviewed_by_id
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :audit_submissions, [ :review_status, :created_at ]
    add_index :audit_submissions, [ :user_id, :project_hash ]
    add_foreign_key :audit_submissions, :users, column: :reviewed_by_id, on_delete: :nullify
  end
end
