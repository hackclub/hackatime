class AddIsSuperadminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :is_superadmin, :boolean, default: false, null: false
  end
end
