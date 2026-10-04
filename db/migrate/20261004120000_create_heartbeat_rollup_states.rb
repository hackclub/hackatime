class CreateHeartbeatRollupStates < ActiveRecord::Migration[8.1]
  def change
    # Which ClickHouse heartbeat_rollups generation is published for each user.
    create_table :heartbeat_rollup_states do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.bigint :generation, null: false
      t.string :timezone, null: false
      t.string :heartbeat_cache_version, null: false

      t.timestamps
    end
  end
end
