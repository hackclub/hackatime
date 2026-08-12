class HeartbeatCutover < ApplicationRecord
  class PurgeBlocked < StandardError; end

  POSTGRESQL_WRITE_ERROR = "PostgreSQL heartbeat writes are unavailable after ClickHouse cutover"

  validates :source_through_id, :backfilled_through_id,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.ensure_postgresql_writes_available!
    raise POSTGRESQL_WRITE_ERROR if where.not(purged_at: nil).exists?
  end

  def self.with_postgresql_ingest_lock(&block)
    transaction do
      cutover = lock.find_by(id: 1)
      raise POSTGRESQL_WRITE_ERROR if cutover&.purged_at?

      yield
    end
  end

  def purge_postgresql!
    transaction(requires_new: true) do
      lock!
      unless verified_through_id == source_through_id && verified_at?
        raise PurgeBlocked, "The recorded ClickHouse verification is stale"
      end

      current_max_id = Heartbeat.postgresql_unscoped.maximum(:id).to_i
      if current_max_id != source_through_id
        raise PurgeBlocked, "PostgreSQL received heartbeats after the recorded source boundary"
      end

      update!(purged_at: Time.current)
      self.class.connection.execute("TRUNCATE TABLE heartbeats, dashboard_rollups")
      User.update_all(dashboard_rollup_generation: 0, dashboard_rollup_refreshed_generation: 0)
    end
  end
end
