class AddLeaderboardOptOutToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :leaderboard_opt_out, :boolean, default: false, null: false
  end
end
