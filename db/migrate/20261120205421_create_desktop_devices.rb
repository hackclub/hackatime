class CreateDesktopDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :desktop_devices do |t|
      t.references :user, null: false, foreign_key: true
      t.string :uid, null: false
      t.string :name, null: false
      t.string :platform, null: false
      t.string :app_version
      t.string :token_digest, null: false
      t.text :public_key
      t.integer :key_tier, null: false, default: 0
      t.string :hardware_id_digest
      t.string :app_attest_key_id
      t.datetime :attested_at
      t.integer :last_seq, null: false, default: 0
      t.string :head_hash, null: false, default: "0" * 64
      t.bigint :last_minute
      t.bigint :last_mono_ms
      t.datetime :last_seen_at
      t.datetime :capture_consented_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :desktop_devices, :uid, unique: true
    add_index :desktop_devices, :token_digest, unique: true
    add_index :desktop_devices, :hardware_id_digest, unique: true, where: "revoked_at IS NULL AND hardware_id_digest IS NOT NULL"
  end
end
