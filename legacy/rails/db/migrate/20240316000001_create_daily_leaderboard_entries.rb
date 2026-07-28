class CreateDailyLeaderboardEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_leaderboard_entries do |t|
      t.references :daily_leaderboard, null: false, foreign_key: true
      t.string :user_id, null: false
      t.integer :total_seconds, null: false, default: 0
      t.integer :rank
      t.timestamps

      t.index [ :daily_leaderboard_id, :user_id ], unique: true, name: 'idx_leaderboard_entries_on_leaderboard_and_user'
    end
  end
end
