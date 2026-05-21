class AddLeaderboardEligiblePartialIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_heartbeats_lb_eligible_user_time
      ON heartbeats (user_id, time)
      WHERE deleted_at IS NULL
        AND category = 'coding'
        AND (
          editor IS NULL
          OR lower(editor) NOT IN (
            'arc', 'brave', 'chrome', 'chromium', 'edge', 'firefox', 'floorp',
            'librewolf', 'microsoft-edge', 'opera', 'opera-gx', 'safari',
            'vivaldi', 'waterfox', 'zen'
          )
        )
    SQL
  end

  def down
    remove_index :heartbeats, name: :idx_heartbeats_lb_eligible_user_time, algorithm: :concurrently, if_exists: true
  end
end
