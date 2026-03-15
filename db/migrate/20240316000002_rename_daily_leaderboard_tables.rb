class RenameDailyLeaderboardTables < ActiveRecord::Migration[8.1]
  def change
    rename_table :daily_leaderboards, :leaderboards
    rename_table :daily_leaderboard_entries, :leaderboard_entries

    # Update the foreign key
    rename_column :leaderboard_entries, :daily_leaderboard_id, :leaderboard_id
  end
end
