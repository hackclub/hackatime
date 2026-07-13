module Clickhouse
  class HeartbeatIntervalDelta < Clickhouse::Record
    self.table_name = "heartbeat_interval_deltas"
    self.primary_key = "delta_id"
  end
end
