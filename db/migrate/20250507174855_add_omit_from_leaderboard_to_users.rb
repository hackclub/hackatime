class AddOmitFromLeaderboardToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :omit_from_leaderboard, :boolean, default: false, null: false
  end
end
