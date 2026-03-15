class AddIndexToLeaderboardsStartDate < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :leaderboards, :start_date,
              where: "deleted_at IS NULL",
              algorithm: :concurrently
  end
end
