class RenameCustomUsername < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :custom_name, :username
  end
end
