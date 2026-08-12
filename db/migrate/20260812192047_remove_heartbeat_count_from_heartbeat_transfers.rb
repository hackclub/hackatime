class RemoveHeartbeatCountFromHeartbeatTransfers < ActiveRecord::Migration[8.1]
  def change
    remove_column :heartbeat_transfers, :heartbeat_count, :integer
  end
end
