class AddHeartbeatsUserProjectTimeCoveringIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :heartbeats, [ :user_id, :project, :time ],
      name: "idx_heartbeats_user_project_time_covering",
      where: "deleted_at IS NULL",
      include: [ :category ],
      algorithm: :concurrently
  end

  def down
    remove_index :heartbeats,
      name: "idx_heartbeats_user_project_time_covering",
      algorithm: :concurrently
  end
end
