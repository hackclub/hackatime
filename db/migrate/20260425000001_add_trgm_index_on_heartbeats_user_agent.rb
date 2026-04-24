class AddTrgmIndexOnHeartbeatsUserAgent < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    enable_extension :pg_trgm unless extension_enabled?(:pg_trgm)

    # GIN trigram index lets ILIKE '%segment%' on user_agent run in milliseconds
    # instead of seq-scanning the heartbeats table.
    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_heartbeats_on_user_agent_trgm
        ON heartbeats
        USING gin (user_agent gin_trgm_ops)
    SQL
  end

  def down
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_heartbeats_on_user_agent_trgm"
  end
end
