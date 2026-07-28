class CreateTrustLevelAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :trust_level_audit_logs do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.references :changed_by, null: false, foreign_key: { to_table: :users }, index: true
      t.string :previous_trust_level, null: false
      t.string :new_trust_level, null: false
      t.text :reason, null: true
      t.text :notes, null: true

      t.timestamps null: false
    end

    add_index :trust_level_audit_logs, [ :user_id, :created_at ], name: 'index_trust_level_audit_logs_on_user_and_created_at'
    add_index :trust_level_audit_logs, [ :changed_by_id, :created_at ], name: 'index_trust_level_audit_logs_on_changed_by_and_created_at'
  end
end
