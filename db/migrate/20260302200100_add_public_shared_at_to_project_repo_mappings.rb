class AddPublicSharedAtToProjectRepoMappings < ActiveRecord::Migration[8.1]
  def change
    add_column :project_repo_mappings, :public_shared_at, :datetime
  end
end
