class DropUnusedHeartbeatUserAgents < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :heartbeats, :heartbeat_user_agents, column: :user_agent_id, if_exists: true
    remove_column :heartbeats, :user_agent_id, :bigint, if_exists: true
    drop_table :heartbeat_user_agents, if_exists: true
  end
end
