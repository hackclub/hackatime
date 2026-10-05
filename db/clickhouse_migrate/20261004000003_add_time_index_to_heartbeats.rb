# Site-wide reads (currently hacking, footer counts, active users, leaderboards,
# weekly summaries) filter on time alone. ORDER BY starts with user_id, so
# without a skip index they read the newest granules of every user.
class AddTimeIndexToHeartbeats < ActiveRecord::Migration[8.1]
  def up
    execute "ALTER TABLE heartbeats ADD INDEX IF NOT EXISTS time_minmax time TYPE minmax GRANULARITY 1"
    execute "ALTER TABLE heartbeats MATERIALIZE INDEX time_minmax SETTINGS mutations_sync = 1"
  end

  def down
    execute "ALTER TABLE heartbeats DROP INDEX IF EXISTS time_minmax"
  end
end
