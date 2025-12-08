class AddHCAFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :hca_id, :string
    add_column :users, :hca_scopes, :string, array: true, default: []
    add_column :users, :hca_access_token, :string
  end
end
