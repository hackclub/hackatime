class CleanUpWeeklyLeaderboards < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM leaderboards WHERE period_type = 1"
    execute "DELETE FROM leaderboards WHERE timezone_utc_offset IS NOT NULL"
  end

  def down
    # no revert
  end
end
