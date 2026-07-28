class AllowNullRepoUrlOnProjectRepoMappings < ActiveRecord::Migration[8.1]
  def change
    change_column_null :project_repo_mappings, :repo_url, true
  end
end
