class AddLeaderboardShadowbanToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :leaderboard_shadowbanned, :boolean, default: false, null: false
    add_column :users, :leaderboard_shadowban_reason, :text
    add_index :users, :leaderboard_shadowbanned, where: "leaderboard_shadowbanned = true"
  end
end
