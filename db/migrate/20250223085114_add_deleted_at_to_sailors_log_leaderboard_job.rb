class AddDeletedAtToSailorsLogLeaderboardJob < ActiveRecord::Migration[8.1]
  def change
    add_column :sailors_log_leaderboards, :deleted_at, :datetime, default: nil
  end
end
