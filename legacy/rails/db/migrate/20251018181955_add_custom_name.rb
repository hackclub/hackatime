class AddCustomName < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :custom_name, :string
  end
end
