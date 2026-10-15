class AddParticipationCacheVersionToSailorsLogLeaderboards < ActiveRecord::Migration[8.1]
  def change
    add_column :sailors_log_leaderboards, :participation_cache_version, :string
  end
end
