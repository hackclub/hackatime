class AddIndexToSailorsLogsSlackUid < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :sailors_logs, :slack_uid,
      unique: true,
      algorithm: :concurrently
  end
end
