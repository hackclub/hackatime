class CreateStruggleConversions < ActiveRecord::Migration[8.1]
  def change
    create_table :struggle_conversions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :project_hash, limit: 64
      t.string :project_name, limit: 128
      t.integer :windows_count, null: false
      t.decimal :total_sp_converted, precision: 10, scale: 2, null: false
      t.integer :total_raw_seconds, null: false
      t.integer :total_credited_seconds, null: false
      t.datetime :converted_at, null: false

      t.timestamps
    end

    add_index :struggle_conversions, [ :user_id, :converted_at ]
  end
end
