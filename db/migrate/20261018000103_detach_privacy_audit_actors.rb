class DetachPrivacyAuditActors < ActiveRecord::Migration[8.1]
  def change
    change_column_null :trust_level_audit_logs, :changed_by_id, true
  end
end
