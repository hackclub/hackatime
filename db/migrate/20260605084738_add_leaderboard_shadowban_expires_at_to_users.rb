class AddLeaderboardShadowbanExpiresAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :leaderboard_shadowban_expires_at, :datetime
  end
end
