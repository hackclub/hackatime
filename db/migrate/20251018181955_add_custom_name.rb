class AddCustomName < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :custom_name, :string
  end
end
