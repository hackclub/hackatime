class AddHeartbeatOperationIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :heartbeat_transfers, :from_user_id
    add_index :heartbeat_transfers, :to_user_id
    add_index :heartbeat_deletions, :user_id, unique: true
  end
end
