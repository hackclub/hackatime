class CreateHeartbeatTransfers < ActiveRecord::Migration[8.0]
  def change
    create_table :heartbeat_transfers do |t|
      t.bigint :from_user_id, null: false
      t.bigint :to_user_id, null: false
      t.integer :heartbeat_count, null: false
      t.integer :status, null: false, default: 0
      t.datetime :copied_at
      t.datetime :completed_at
      t.text :last_error
      t.timestamps
    end

    add_index :heartbeat_transfers, :status
  end
end
