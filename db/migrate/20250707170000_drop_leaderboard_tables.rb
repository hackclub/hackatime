class DropLeaderboardTables < ActiveRecord::Migration[7.0]
  def change
    drop_table :leaderboards, if_exists: true
    drop_table :leaderboard_entries, if_exists: true
    drop_table :sailors_log_leaderboards, if_exists: true
  end
end
