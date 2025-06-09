class UpdateProjectRepoMappingsToUseRepository < ActiveRecord::Migration[8.0]
  def change
    # Add repository reference
    add_reference :project_repo_mappings, :repository, null: true, foreign_key: true
  end
end
