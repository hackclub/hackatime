# Base class for models stored in ClickHouse (currently only Heartbeat).
#
# ClickHouse has no transactions, no rollback and no uniqueness constraints, and
# the adapter turns update_all into a heavy ALTER TABLE mutation. Write through
# the explicit helpers on each model instead of generic Active Record writes.
class ClickhouseRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :clickhouse, reading: :clickhouse }

  # Settings for request-path writes: let ClickHouse batch small inserts, but
  # only acknowledge once the data is durable.
  INGEST_INSERT_SETTINGS = { async_insert: 1, wait_for_async_insert: 1 }.freeze
  # Settings for writes whose rows must be visible to the very next query
  # (tests, rollup rebuilds) and must never be dropped as a "duplicate" block.
  SYNC_INSERT_SETTINGS = { async_insert: 0, insert_deduplicate: 0, deduplicate_insert: "disable" }.freeze

  class << self
    # Runs a statement with ClickHouse query settings applied to every request
    # made inside the block.
    def with_clickhouse_settings(**settings, &block)
      connection.with_settings(**settings, &block)
    end

    def quote_clickhouse(value) = connection.quote(value)
  end
end
