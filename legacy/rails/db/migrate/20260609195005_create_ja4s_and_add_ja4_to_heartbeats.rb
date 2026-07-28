class CreateJa4sAndAddJa4ToHeartbeats < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    create_table :ja4s, id: :integer, if_not_exists: true do |t|
      t.text :fingerprint, null: false
      t.timestamps
    end

    add_index :ja4s, :fingerprint, unique: true, if_not_exists: true

    add_column :heartbeats, :ja4_id, :integer, if_not_exists: true
    add_index :heartbeats, :ja4_id, where: "ja4_id IS NOT NULL", algorithm: :concurrently, if_not_exists: true

    unless foreign_key_exists?(:heartbeats, :ja4s)
      add_foreign_key :heartbeats, :ja4s, on_delete: :nullify, validate: false
    end
  end

  def down
    remove_foreign_key :heartbeats, :ja4s if foreign_key_exists?(:heartbeats, :ja4s)
    remove_index :heartbeats, name: :index_heartbeats_on_ja4_id, algorithm: :concurrently, if_exists: true
    remove_column :heartbeats, :ja4_id, if_exists: true
    drop_table :ja4s, if_exists: true
  end
end
