class DropUnusedHeartbeatLookupTables < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :heartbeats, :heartbeat_branches, column: :branch_id, if_exists: true
    remove_foreign_key :heartbeats, :heartbeat_categories, column: :category_id, if_exists: true
    remove_foreign_key :heartbeats, :heartbeat_editors, column: :editor_id, if_exists: true
    remove_foreign_key :heartbeats, :heartbeat_languages, column: :language_id, if_exists: true
    remove_foreign_key :heartbeats, :heartbeat_machines, column: :machine_id, if_exists: true
    remove_foreign_key :heartbeats, :heartbeat_operating_systems, column: :operating_system_id, if_exists: true
    remove_foreign_key :heartbeats, :heartbeat_projects, column: :project_id, if_exists: true

    remove_column :heartbeats, :branch_id, :bigint, if_exists: true
    remove_column :heartbeats, :category_id, :bigint, if_exists: true
    remove_column :heartbeats, :editor_id, :bigint, if_exists: true
    remove_column :heartbeats, :language_id, :bigint, if_exists: true
    remove_column :heartbeats, :machine_id, :bigint, if_exists: true
    remove_column :heartbeats, :operating_system_id, :bigint, if_exists: true
    remove_column :heartbeats, :project_id, :bigint, if_exists: true

    drop_table :heartbeat_branches, if_exists: true
    drop_table :heartbeat_categories, if_exists: true
    drop_table :heartbeat_editors, if_exists: true
    drop_table :heartbeat_languages, if_exists: true
    drop_table :heartbeat_machines, if_exists: true
    drop_table :heartbeat_operating_systems, if_exists: true
    drop_table :heartbeat_projects, if_exists: true
  end
end
