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

CREATE TABLE heartbeat_rollups
(
    `user_id` UInt64,
    `generation` UInt64,
    `local_date` Date32,
    `hour` UInt8,
    `project` LowCardinality(Nullable(String)),
    `language` LowCardinality(Nullable(String)),
    `editor` LowCardinality(Nullable(String)),
    `operating_system` LowCardinality(Nullable(String)),
    `category` LowCardinality(Nullable(String)),
    `heartbeats` UInt64,
    `duration` Float64,
    `project_duration` Float64,
    `day_duration` Float64,
    `project_week_duration` Float64,
    `first_time` Float64,
    `last_time` Float64
)
ENGINE = MergeTree
ORDER BY (user_id, generation, local_date, hour)
SETTINGS enable_block_number_column = 1, enable_block_offset_column = 1, index_granularity = 8192;

CREATE TABLE heartbeats
(
    `id` UInt64 CODEC(Delta(8), LZ4),
    `user_id` UInt64 CODEC(T64, ZSTD(1)),
    `time` Float64 CODEC(Gorilla(8), ZSTD(1)),
    `project` Nullable(String) CODEC(ZSTD(3)),
    `branch` Nullable(String) CODEC(ZSTD(3)),
    `entity` Nullable(String) CODEC(ZSTD(3)),
    `category` LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    `editor` LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    `language` LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    `machine` LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    `operating_system` LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    `type` LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    `user_agent` Nullable(String) CODEC(ZSTD(3)),
    `ip_address` Nullable(String) CODEC(ZSTD(1)),
    `dependencies` Array(String) CODEC(ZSTD(3)),
    `dependencies_is_null` Bool DEFAULT false CODEC(ZSTD(1)),
    `dependencies_json` Nullable(String) CODEC(ZSTD(3)),
    `lineno` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `lines` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `cursorpos` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `line_additions` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `line_deletions` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `project_root_count` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `is_write` Nullable(Bool) CODEC(ZSTD(1)),
    `source_type` UInt8 CODEC(T64, ZSTD(1)),
    `ja4_id` Nullable(UInt64) CODEC(T64, ZSTD(1)),
    `ai_model` Nullable(String) CODEC(ZSTD(3)),
    `ai_session` Nullable(String) CODEC(ZSTD(3)),
    `ai_subscription_plan` LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
    `ai_input_tokens` Nullable(Int64) CODEC(T64, ZSTD(1)),
    `ai_output_tokens` Nullable(Int64) CODEC(T64, ZSTD(1)),
    `ai_prompt_length` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `ai_line_changes` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `human_line_changes` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `deleted_at` Nullable(DateTime('UTC')) CODEC(Delta(4), ZSTD(1)),
    `created_at` DateTime('UTC') CODEC(Delta(4), ZSTD(1)),
    `updated_at` DateTime('UTC') CODEC(Delta(4), ZSTD(1)),
    INDEX time_minmax time TYPE minmax GRANULARITY 1
)
ENGINE = MergeTree
ORDER BY (user_id, time, id)
SETTINGS index_granularity = 1024, enable_block_number_column = 1, enable_block_offset_column = 1, non_replicated_deduplication_window = 1000;

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
('20261004000003'),
('20261004000002'),
('20261004000001');

