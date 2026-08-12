class CreateHeartbeatJa4Nullifications < ActiveRecord::Migration[8.0]
  def change
    create_table :heartbeat_ja4_nullifications do |t|
      t.integer :ja4_id, null: false
      t.datetime :completed_at
      t.text :last_error
      t.timestamps
    end

    add_index :heartbeat_ja4_nullifications, :ja4_id, unique: true
    add_index :heartbeat_ja4_nullifications, :completed_at
  end
end
