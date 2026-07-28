class AddDefaultTimezoneLeaderboardToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :default_timezone_leaderboard, :boolean, default: true, null: false, if_not_exists: true
  end
end
