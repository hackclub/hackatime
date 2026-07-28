class CreateAdminApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_api_keys do |t|
      t.references :user, null: false, foreign_key: true
      t.text :name, null: false
      t.text :token, null: false
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :admin_api_keys, :token, unique: true
    add_index :admin_api_keys, [ :user_id, :name ], unique: true
  end
end
