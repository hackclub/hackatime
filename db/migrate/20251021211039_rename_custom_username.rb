class RenameCustomUsername < ActiveRecord::Migration[8.0]
  def change
    rename_column :users, :custom_name, :username
  end
end
