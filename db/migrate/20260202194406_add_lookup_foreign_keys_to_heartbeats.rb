class AddLookupForeignKeysToHeartbeats < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :heartbeats, :language_id, :bigint
    add_column :heartbeats, :category_id, :bigint
    add_column :heartbeats, :editor_id, :bigint
    add_column :heartbeats, :operating_system_id, :bigint
    add_column :heartbeats, :user_agent_id, :bigint
    add_column :heartbeats, :project_id, :bigint
    add_column :heartbeats, :branch_id, :bigint
    add_column :heartbeats, :machine_id, :bigint

    add_index :heartbeats, :language_id, algorithm: :concurrently
    add_index :heartbeats, :category_id, algorithm: :concurrently
    add_index :heartbeats, :editor_id, algorithm: :concurrently
    add_index :heartbeats, :operating_system_id, algorithm: :concurrently
    add_index :heartbeats, :user_agent_id, algorithm: :concurrently
    add_index :heartbeats, :project_id, algorithm: :concurrently
    add_index :heartbeats, :branch_id, algorithm: :concurrently
    add_index :heartbeats, :machine_id, algorithm: :concurrently

    add_index :heartbeats, [ :user_id, :time, :project_id ],
              name: "idx_heartbeats_user_time_project_id",
              algorithm: :concurrently,
              where: "deleted_at IS NULL"

    add_index :heartbeats, [ :user_id, :time, :language_id ],
              name: "idx_heartbeats_user_time_language_id",
              algorithm: :concurrently,
              where: "deleted_at IS NULL"
  end
end
