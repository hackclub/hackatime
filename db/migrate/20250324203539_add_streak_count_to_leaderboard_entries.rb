class AddStreakCountToLeaderboardEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :leaderboard_entries, :streak_count, :integer, default: 0
  end
end
