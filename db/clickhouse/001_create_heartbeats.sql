-- Canonical heartbeat store. ClickHouse is the source of truth for heartbeats.
--
-- Plain MergeTree (not ReplacingMergeTree): reads never need FINAL. Exact
-- duplicates are rejected at ingest by HeartbeatIngest instead of by a merge.
-- Sort key matches nearly every read: one user's heartbeats in time order.
-- Nullable is kept only where the app distinguishes NULL from empty.
CREATE TABLE IF NOT EXISTS heartbeats
(
    id UInt64 CODEC(Delta(8), LZ4),
    user_id UInt64 CODEC(T64, ZSTD(1)),
    time Float64 CODEC(Gorilla, ZSTD(1)),
    project Nullable(String) CODEC(ZSTD(3)),
    branch Nullable(String) CODEC(ZSTD(3)),
    entity Nullable(String) CODEC(ZSTD(3)),
    category LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    editor LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    language LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    machine LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    operating_system LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    type LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    user_agent Nullable(String) CODEC(ZSTD(3)),
    ip_address Nullable(String) CODEC(ZSTD(1)),
    dependencies Array(String) CODEC(ZSTD(3)),
    dependencies_is_null Bool DEFAULT false CODEC(ZSTD(1)),
    -- Postgres allowed multidimensional varchar[]; 43 legacy rows keep their raw text here.
    dependencies_json Nullable(String) CODEC(ZSTD(3)),
    lineno Nullable(Int32) CODEC(T64, ZSTD(1)),
    lines Nullable(Int32) CODEC(T64, ZSTD(1)),
    cursorpos Nullable(Int32) CODEC(T64, ZSTD(1)),
    line_additions Nullable(Int32) CODEC(T64, ZSTD(1)),
    line_deletions Nullable(Int32) CODEC(T64, ZSTD(1)),
    project_root_count Nullable(Int32) CODEC(T64, ZSTD(1)),
    is_write Nullable(Bool) CODEC(ZSTD(1)),
    source_type UInt8 CODEC(T64, ZSTD(1)),
    ja4_id Nullable(UInt64) CODEC(T64, ZSTD(1)),
    ai_model Nullable(String) CODEC(ZSTD(3)),
    ai_session Nullable(String) CODEC(ZSTD(3)),
    ai_subscription_plan LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    ai_input_tokens Nullable(Int64) CODEC(T64, ZSTD(1)),
    ai_output_tokens Nullable(Int64) CODEC(T64, ZSTD(1)),
    ai_prompt_length Nullable(Int32) CODEC(T64, ZSTD(1)),
    ai_line_changes Nullable(Int32) CODEC(T64, ZSTD(1)),
    human_line_changes Nullable(Int32) CODEC(T64, ZSTD(1)),
    -- Whole seconds: about a third of the size of microseconds, and nothing
    -- reads these more finely.
    deleted_at Nullable(DateTime('UTC')) CODEC(Delta(4), ZSTD(1)),
    created_at DateTime('UTC') CODEC(Delta(4), ZSTD(1)),
    updated_at DateTime('UTC') CODEC(Delta(4), ZSTD(1))
)
ENGINE = MergeTree
ORDER BY (user_id, time, id)
SETTINGS index_granularity = 1024,
         -- Lightweight UPDATE (soft delete, anonymisation, JA4 nullification).
         enable_block_number_column = 1,
         enable_block_offset_column = 1,
         -- Makes a retried identical INSERT a no-op on a single node.
         non_replicated_deduplication_window = 1000
