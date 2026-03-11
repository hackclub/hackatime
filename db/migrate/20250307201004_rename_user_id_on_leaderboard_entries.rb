class RenameUserIdOnLeaderboardEntries < ActiveRecord::Migration[8.1]
  def change
    rename_column :leaderboard_entries, :user_id, :slack_uid
  end
end
