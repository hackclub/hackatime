CREATE TABLE ar_internal_metadata
(
    `key` String,
    `value` Nullable(String),
    `created_at` DateTime,
    `updated_at` DateTime
)
ENGINE = ReplacingMergeTree(created_at)
PARTITION BY key
ORDER BY key
SETTINGS index_granularity = 8192;

CREATE TABLE heartbeats
(
    `id` UInt64 CODEC(Delta(8), LZ4),
    `user_id` UInt32 CODEC(T64, ZSTD(1)),
    `time` Float64 CODEC(Gorilla(8), ZSTD(1)),
    `project` Nullable(String) CODEC(ZSTD(3)),
    `branch` Nullable(String) CODEC(ZSTD(3)),
    `category` LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    `editor` LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    `entity` Nullable(String) CODEC(ZSTD(3)),
    `language` LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    `machine` LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    `operating_system` LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    `user_agent` Nullable(String) CODEC(ZSTD(3)),
    `lineno` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `lines` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `cursorpos` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `line_additions` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `line_deletions` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `project_root_count` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `is_write` Nullable(Bool),
    `source_type` UInt8 CODEC(T64, ZSTD(1)),
    `ip_address` Nullable(String) CODEC(ZSTD(1)),
    `dependencies` Array(String) CODEC(ZSTD(3)),
    `ja4_id` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `fields_hash` FixedString(32) CODEC(ZSTD(1)),
    `deleted_at` Nullable(DateTime64(6, 'UTC')) CODEC(Delta(8), ZSTD(1)),
    `created_at` DateTime64(6, 'UTC') CODEC(Delta(8), ZSTD(1)),
    `updated_at` DateTime64(6, 'UTC') CODEC(Delta(8), ZSTD(1)),
    `version` UInt64 CODEC(Delta(8), ZSTD(1)),
    `type` LowCardinality(Nullable(String)) CODEC(ZSTD(1))
)
ENGINE = ReplacingMergeTree(version)
PARTITION BY toYYYYMM(toDateTime(time))
ORDER BY (user_id, time, fields_hash)
SETTINGS index_granularity = 8192;

CREATE TABLE schema_migrations
(
    `version` String,
    `active` Int8 DEFAULT 1,
    `ver` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(ver)
ORDER BY (version)
SETTINGS index_granularity = 8192;

INSERT INTO schema_migrations (version) VALUES
('20260708000001'),
('20260706000001');

