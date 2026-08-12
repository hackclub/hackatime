CREATE TABLE IF NOT EXISTS heartbeat_aliases
(
    user_id UInt64 CODEC(T64, ZSTD(1)),
    fields_hash FixedString(32) CODEC(ZSTD(1)),
    heartbeat_id UInt64 CODEC(Delta(8), LZ4),
    active Bool CODEC(ZSTD(1)),
    alias_version UInt64 CODEC(T64, ZSTD(1)),
    updated_at DateTime64(6, 'UTC') CODEC(Delta(8), ZSTD(1)),
    INDEX heartbeat_id_lookup heartbeat_id TYPE bloom_filter(0.001) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(alias_version)
PRIMARY KEY (user_id, fields_hash)
ORDER BY (user_id, fields_hash)
SETTINGS index_granularity = 8192,
         non_replicated_deduplication_window = 10000
