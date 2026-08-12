class CreateHeartbeatDeletions < ActiveRecord::Migration[8.0]
  def change
    create_table :heartbeat_deletions do |t|
      t.bigint :user_id, null: false
      t.integer :status, null: false, default: 0
      t.datetime :completed_at
      t.text :last_error
      t.timestamps
    end

    add_index :heartbeat_deletions, :status
  end
end
