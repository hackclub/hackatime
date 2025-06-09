class AddIndexToLeaderboardsStartDate < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :leaderboards, :start_date,
              where: "deleted_at IS NULL",
              algorithm: :concurrently
  end
end
