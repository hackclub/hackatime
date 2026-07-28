class AddLeaderboardShadowbannedByToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :leaderboard_shadowbanned_by, foreign_key: { to_table: :users }
  end
end
