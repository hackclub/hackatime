class AddHeartbeatsLeaderboardAndTimeUserIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :heartbeats, [ :user_id, :category, :time ],
      name: "idx_heartbeats_user_category_time_incl_editor",
      where: "deleted_at IS NULL",
      include: [ :editor ],
      algorithm: :concurrently

    remove_index :heartbeats, name: "idx_heartbeats_user_category_time",
      algorithm: :concurrently, if_exists: true

    add_index :heartbeats, [ :time, :user_id ],
      name: "idx_heartbeats_time_user_active",
      where: "deleted_at IS NULL",
      algorithm: :concurrently
  end
end
