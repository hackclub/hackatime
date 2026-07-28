class AddArchivedAtToProjectRepoMappings < ActiveRecord::Migration[8.1]
  def change
    add_column :project_repo_mappings, :archived_at, :datetime
    add_index :project_repo_mappings, [ :user_id, :archived_at ]
  end
end
