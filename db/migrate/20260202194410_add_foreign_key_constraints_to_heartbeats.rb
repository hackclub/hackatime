class AddForeignKeyConstraintsToHeartbeats < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :heartbeats, :heartbeat_languages, column: :language_id, validate: false
    add_foreign_key :heartbeats, :heartbeat_categories, column: :category_id, validate: false
    add_foreign_key :heartbeats, :heartbeat_editors, column: :editor_id, validate: false
    add_foreign_key :heartbeats, :heartbeat_operating_systems, column: :operating_system_id, validate: false
    add_foreign_key :heartbeats, :heartbeat_user_agents, column: :user_agent_id, validate: false
    add_foreign_key :heartbeats, :heartbeat_projects, column: :project_id, validate: false
    add_foreign_key :heartbeats, :heartbeat_branches, column: :branch_id, validate: false
    add_foreign_key :heartbeats, :heartbeat_machines, column: :machine_id, validate: false
  end
end
