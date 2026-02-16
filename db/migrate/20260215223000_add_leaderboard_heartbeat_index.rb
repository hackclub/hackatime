class AddLeaderboardHeartbeatIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :heartbeats,
      [ :time, :user_id ],
      where: "(deleted_at IS NULL AND category = 'coding')",
      name: "idx_heartbeats_coding_time_user",
      algorithm: :concurrently
  end
end
