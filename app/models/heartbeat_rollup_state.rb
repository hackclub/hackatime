# The heartbeat_rollups generation published for a user. ClickHouse has no
# transactions, so a rebuild writes a new generation and then publishes it here;
# readers only ever query the published generation.
class HeartbeatRollupState < ApplicationRecord
  belongs_to :user

  # The user's published state, or nil when there is none or it was built for
  # another timezone or set of heartbeat exclusions.
  def self.current_for(user)
    state = find_by(user_id: user.id)
    state if state && state.timezone == user.timezone && state.heartbeat_cache_version == user.heartbeat_cache_version
  end

  # Publishes a generation unless a newer one is already published.
  def self.publish!(user_id:, generation:, timezone:, heartbeat_cache_version:)
    sql = sanitize_sql_array([ <<~SQL.squish, user_id, generation, timezone, heartbeat_cache_version ])
      INSERT INTO heartbeat_rollup_states (user_id, generation, timezone, heartbeat_cache_version, created_at, updated_at)
      VALUES (?, ?, ?, ?, NOW(), NOW())
      ON CONFLICT (user_id) DO UPDATE
      SET generation = EXCLUDED.generation, timezone = EXCLUDED.timezone,
          heartbeat_cache_version = EXCLUDED.heartbeat_cache_version, updated_at = EXCLUDED.updated_at
      WHERE heartbeat_rollup_states.generation < EXCLUDED.generation
    SQL
    connection.exec_update(sql) == 1
  end
end
