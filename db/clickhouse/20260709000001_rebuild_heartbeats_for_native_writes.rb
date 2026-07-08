# Heartbeats are now written directly to ClickHouse (no Postgres copy, no
# mirror). Rebuild the table to the canonical schema shared with production:
# - fields_hash is String (matches prod; FixedString(32) padded on dev only)
# - _peerdb_* compat columns remain so the production PeerDB bridge can keep
#   writing during the cutover window; `version DEFAULT _peerdb_version` makes
#   CDC rows order correctly while app rows supply version explicitly.
# Dev/test data is disposable — reseed after migrating.
class RebuildHeartbeatsForNativeWrites < ActiveRecord::Migration[8.1]
  def up
    execute "DROP TABLE IF EXISTS heartbeats"
    execute <<~SQL
      CREATE TABLE heartbeats
      (
          id                 UInt64                             CODEC(Delta(8), LZ4),
          user_id            UInt32                             CODEC(T64, ZSTD(1)),
          time               Float64                            CODEC(Gorilla, ZSTD(1)),
          fields_hash        String                             CODEC(ZSTD(1)),
          project            Nullable(String)                   CODEC(ZSTD(3)),
          branch             Nullable(String)                   CODEC(ZSTD(3)),
          entity             Nullable(String)                   CODEC(ZSTD(3)),
          category           LowCardinality(Nullable(String))   CODEC(ZSTD(1)),
          editor             LowCardinality(Nullable(String))   CODEC(ZSTD(1)),
          language           LowCardinality(Nullable(String))   CODEC(ZSTD(1)),
          machine            LowCardinality(Nullable(String))   CODEC(ZSTD(1)),
          operating_system   LowCardinality(Nullable(String))   CODEC(ZSTD(1)),
          type               LowCardinality(Nullable(String))   CODEC(ZSTD(1)),
          user_agent         Nullable(String)                   CODEC(ZSTD(3)),
          ip_address         Nullable(String)                   CODEC(ZSTD(1)),
          dependencies       Array(String)                      CODEC(ZSTD(3)),
          lineno             Nullable(Int32)                    CODEC(T64, ZSTD(1)),
          lines              Nullable(Int32)                    CODEC(T64, ZSTD(1)),
          cursorpos          Nullable(Int32)                    CODEC(T64, ZSTD(1)),
          line_additions     Nullable(Int32)                    CODEC(T64, ZSTD(1)),
          line_deletions     Nullable(Int32)                    CODEC(T64, ZSTD(1)),
          project_root_count Nullable(Int32)                    CODEC(T64, ZSTD(1)),
          is_write           Nullable(Bool)                     CODEC(ZSTD(1)),
          source_type        UInt8                              CODEC(T64, ZSTD(1)),
          ysws_program       UInt8 DEFAULT 0                    CODEC(T64, ZSTD(1)),
          ja4_id             Nullable(Int32)                    CODEC(T64, ZSTD(1)),
          deleted_at         Nullable(DateTime64(6, 'UTC'))     CODEC(Delta(8), ZSTD(1)),
          created_at         DateTime64(6, 'UTC')               CODEC(Delta(8), ZSTD(1)),
          updated_at         DateTime64(6, 'UTC')               CODEC(Delta(8), ZSTD(1)),
          _peerdb_synced_at  DateTime64(9) DEFAULT now64()      CODEC(Delta(8), ZSTD(1)),
          _peerdb_is_deleted UInt8 DEFAULT 0                    CODEC(ZSTD(1)),
          _peerdb_version    UInt64 DEFAULT 0                   CODEC(T64, ZSTD(1)),
          version            UInt64 DEFAULT _peerdb_version     CODEC(T64, ZSTD(1))
      )
      ENGINE = ReplacingMergeTree(version)
      PARTITION BY toYYYYMM(toDateTime(time))
      PRIMARY KEY (user_id, time)
      ORDER BY (user_id, time, fields_hash)
      SETTINGS index_granularity = 8192
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
