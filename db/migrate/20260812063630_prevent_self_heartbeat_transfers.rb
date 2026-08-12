class PreventSelfHeartbeatTransfers < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :heartbeat_transfers,
      "from_user_id <> to_user_id",
      name: "heartbeat_transfers_distinct_users"
  end
end
