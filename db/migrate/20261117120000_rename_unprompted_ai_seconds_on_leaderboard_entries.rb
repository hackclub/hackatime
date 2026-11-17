class RenameUnpromptedAiSecondsOnLeaderboardEntries < ActiveRecord::Migration[8.1]
  def change
    rename_column :leaderboard_entries, :unprompted_ai_seconds, :discounted_ai_seconds
  end
end
