class AddUserProjectTimeIndexToHeartbeats < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :heartbeats, [ :user_id, :project, :time ],
      name: "index_heartbeats_on_user_project_time",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
