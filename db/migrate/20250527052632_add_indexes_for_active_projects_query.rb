class AddIndexesForActiveProjectsQuery < ActiveRecord::Migration[8.0]
  def change
    add_index :heartbeats, [ :source_type, :time, :user_id, :project ],
              name: 'index_heartbeats_on_source_type_time_user_project'

    add_index :project_repo_mappings, :project_name
  end
end
