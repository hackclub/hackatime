class AddEditTrackingToTrustLevelAuditLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :trust_level_audit_logs, :edited_at, :datetime
    add_reference :trust_level_audit_logs, :edited_by, foreign_key: { to_table: :users }
    add_column :trust_level_audit_logs, :original_reason, :text
    add_column :trust_level_audit_logs, :original_notes, :text
  end
end
