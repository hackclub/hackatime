class CreateEvidenceBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :evidence_blocks do |t|
      t.references :desktop_device, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :evidence_beacon, null: false, foreign_key: true
      t.integer :seq, null: false
      t.bigint :minute, null: false
      t.string :prev_hash, null: false
      t.string :block_hash, null: false
      t.jsonb :payload, null: false, default: {}
      t.boolean :signed, null: false, default: false
      t.boolean :offline, null: false, default: false
      t.bigint :captured_at_ms, null: false
      t.datetime :received_at, null: false
      t.inet :ip_address
      t.integer :ja4_id
    end
    add_index :evidence_blocks, [ :desktop_device_id, :seq ], unique: true
    add_index :evidence_blocks, [ :user_id, :minute ]
  end
end
