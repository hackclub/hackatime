class AddHomeFolderProjectWarnedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :home_folder_project_warned_at, :datetime
  end
end
