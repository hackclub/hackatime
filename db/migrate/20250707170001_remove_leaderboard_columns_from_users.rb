class RemoveLeaderboardColumnsFromUsers < ActiveRecord::Migration[7.0]
  def change
    remove_column :users, :default_timezone_leaderboard, :boolean, if_exists: true
    remove_column :users, :omit_from_leaderboard, :boolean, if_exists: true
  end
end
