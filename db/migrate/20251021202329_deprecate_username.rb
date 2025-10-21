class DeprecateUsername < ActiveRecord::Migration[8.0]
  def change
    rename_column :users, :username, :deprecated_name
  end
end
