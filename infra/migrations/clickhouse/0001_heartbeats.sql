CREATE DATABASE IF NOT EXISTS hackatime;

CREATE TABLE IF NOT EXISTS hackatime.heartbeats
(
    id UInt64 CODEC(Delta(8), LZ4),
    user_id Int64 CODEC(T64, ZSTD(1)),
    time Float64 CODEC(Gorilla(8), ZSTD(1)),
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
    lineno Nullable(Int32) CODEC(T64, ZSTD(1)),
    lines Nullable(Int32) CODEC(T64, ZSTD(1)),
    cursorpos Nullable(Int32) CODEC(T64, ZSTD(1)),
    line_additions Nullable(Int32) CODEC(T64, ZSTD(1)),
    line_deletions Nullable(Int32) CODEC(T64, ZSTD(1)),
    project_root_count Nullable(Int32) CODEC(T64, ZSTD(1)),
    is_write Nullable(Bool) CODEC(ZSTD(1)),
    source_type Int32 CODEC(T64, ZSTD(1)),
    ysws_program Int32 DEFAULT 0 CODEC(T64, ZSTD(1)),
    ja4_id Nullable(Int32) CODEC(T64, ZSTD(1)),
    ai_model Nullable(String) CODEC(ZSTD(3)),
    ai_session Nullable(String) CODEC(ZSTD(3)),
    ai_subscription_plan LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    ai_input_tokens Nullable(Int64) CODEC(T64, ZSTD(1)),
    ai_output_tokens Nullable(Int64) CODEC(T64, ZSTD(1)),
    ai_prompt_length Nullable(Int32) CODEC(T64, ZSTD(1)),
    ai_line_changes Nullable(Int32) CODEC(T64, ZSTD(1)),
    human_line_changes Nullable(Int32) CODEC(T64, ZSTD(1)),
    deleted_at Nullable(Float64) CODEC(Gorilla(8), ZSTD(1)),
    created_at Float64 CODEC(Gorilla(8), ZSTD(1)),
    updated_at Float64 CODEC(Gorilla(8), ZSTD(1)),
    version UInt64 CODEC(T64, ZSTD(1))
)
ENGINE = ReplacingMergeTree(version)
PARTITION BY toYYYYMM(toDateTime(time))
PRIMARY KEY (user_id, time)
ORDER BY (user_id, time, id)
SETTINGS index_granularity = 8192;
