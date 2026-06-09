class CreateJa4sAndAddJa4ToHeartbeats < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    create_table :ja4s do |t|
      t.text :fingerprint, null: false
      t.timestamps
    end

    add_index :ja4s, :fingerprint, unique: true

    add_column :heartbeats, :ja4_id, :bigint
    add_index :heartbeats, :ja4_id, algorithm: :concurrently
    add_foreign_key :heartbeats, :ja4s, on_delete: :nullify, validate: false
    validate_foreign_key :heartbeats, :ja4s
  end

  def down
    remove_foreign_key :heartbeats, :ja4s
    remove_index :heartbeats, :ja4_id, algorithm: :concurrently
    remove_column :heartbeats, :ja4_id
    drop_table :ja4s
  end
end
