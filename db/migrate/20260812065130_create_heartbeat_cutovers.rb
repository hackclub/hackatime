class CreateHeartbeatCutovers < ActiveRecord::Migration[8.1]
  def change
    create_table :heartbeat_cutovers do |t|
      t.bigint :source_through_id, null: false
      t.bigint :backfilled_through_id, null: false, default: 0
      t.bigint :verified_through_id
      t.datetime :verified_at
      t.datetime :purged_at
      t.timestamps
    end
  end
end
