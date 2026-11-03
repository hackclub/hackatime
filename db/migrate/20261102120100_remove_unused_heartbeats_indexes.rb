class RemoveUnusedHeartbeatsIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Production last scanned these when the queries they served changed: the user/IP index on 2026-09-02, after
  # the country geocoding job was removed, and the leaderboard index on 2026-10-25, when leaderboards started
  # counting "ai coding" heartbeats and their category filter no longer implied its predicate.
  def up
    remove_index :heartbeats, name: "index_heartbeats_on_user_id_with_ip", algorithm: :concurrently, if_exists: true
    remove_index :heartbeats, name: "idx_heartbeats_lb_eligible_user_time", algorithm: :concurrently, if_exists: true
  end

  def down
    add_index :heartbeats, [ :user_id, :id ], order: { id: :desc }, name: "index_heartbeats_on_user_id_with_ip",
      where: "ip_address IS NOT NULL AND deleted_at IS NULL", algorithm: :concurrently, if_not_exists: true
    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_heartbeats_lb_eligible_user_time ON heartbeats (user_id, time)
      WHERE deleted_at IS NULL AND category = 'coding' AND (editor IS NULL OR lower(editor) NOT IN (
        'arc', 'brave', 'chrome', 'chromium', 'edge', 'firefox', 'floorp', 'librewolf', 'microsoft-edge', 'opera',
        'opera-gx', 'safari', 'vivaldi', 'waterfox', 'zen'))
    SQL
  end
end
