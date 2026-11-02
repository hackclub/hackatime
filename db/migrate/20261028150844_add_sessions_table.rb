class AddSessionsTable < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.string :session_id, null: false
      t.jsonb :data
      t.timestamps
    end

    add_index :sessions, :session_id, unique: true
    add_index :sessions, :updated_at
    add_index :sessions, :data, using: :gin, opclass: :jsonb_path_ops
  end
end
