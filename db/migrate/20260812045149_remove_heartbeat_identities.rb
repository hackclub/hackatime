class RemoveHeartbeatIdentities < ActiveRecord::Migration[8.1]
  def up
    drop_table :heartbeat_identities, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
