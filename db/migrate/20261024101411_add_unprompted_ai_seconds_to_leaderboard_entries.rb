class AddUnpromptedAiSecondsToLeaderboardEntries < ActiveRecord::Migration[8.1]
  def change
    # A constant default is metadata-only on Postgres 11+, so this does not rewrite the table.
    add_column :leaderboard_entries, :unprompted_ai_seconds, :integer, default: 0, null: false
  end
end
