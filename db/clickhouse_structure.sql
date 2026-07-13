CREATE TABLE schema_migrations
(
    `version` String,
    `active` Int8 DEFAULT 1,
    `ver` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(ver)
ORDER BY (version)
SETTINGS index_granularity = 8192;

CREATE TABLE heartbeats
(
    `id` UInt64 CODEC(Delta(8), LZ4),
    `user_id` UInt32 CODEC(T64, ZSTD(1)),
    `time` Float64 CODEC(Gorilla(8), ZSTD(1)),
    `fields_hash` String CODEC(ZSTD(1)),
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
    `lineno` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `lines` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `cursorpos` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `line_additions` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `line_deletions` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `project_root_count` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `is_write` Nullable(Bool) CODEC(ZSTD(1)),
    `source_type` UInt8 CODEC(T64, ZSTD(1)),
    `ysws_program` UInt8 DEFAULT 0 CODEC(T64, ZSTD(1)),
    `ja4_id` Nullable(Int32) CODEC(T64, ZSTD(1)),
    `deleted_at` Nullable(DateTime64(6, 'UTC')) CODEC(Delta(8), ZSTD(1)),
    `created_at` DateTime64(6, 'UTC') CODEC(Delta(8), ZSTD(1)),
    `updated_at` DateTime64(6, 'UTC') CODEC(Delta(8), ZSTD(1)),
    `_peerdb_synced_at` DateTime64(9) DEFAULT now64() CODEC(Delta(8), ZSTD(1)),
    `_peerdb_is_deleted` UInt8 DEFAULT 0 CODEC(ZSTD(1)),
    `_peerdb_version` UInt64 DEFAULT 0 CODEC(T64, ZSTD(1)),
    `version` UInt64 DEFAULT _peerdb_version CODEC(T64, ZSTD(1))
)
ENGINE = ReplacingMergeTree(version)
PARTITION BY toYYYYMM(toDateTime(time))
PRIMARY KEY (user_id, time)
ORDER BY (user_id, time, fields_hash)
SETTINGS index_granularity = 8192;

CREATE TABLE heartbeat_user_daily_stats
(
    `user_id` UInt32 CODEC(T64, ZSTD(1)),
    `day` Date CODEC(Delta(2), ZSTD(1)),
    `seconds` Float64 CODEC(Gorilla(8), ZSTD(1)),
    `first_seconds` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `heartbeat_count` Int64 CODEC(T64, ZSTD(1))
)
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(day)
PRIMARY KEY (user_id, day)
ORDER BY (user_id, day)
SETTINGS index_granularity = 8192;

CREATE TABLE heartbeat_project_summaries
(
    `user_id` UInt32 CODEC(T64, ZSTD(1)),
    `project` LowCardinality(String) CODEC(ZSTD(1)),
    `seconds` Float64 CODEC(Gorilla(8), ZSTD(1)),
    `heartbeat_count` Int64 CODEC(T64, ZSTD(1))
)
ENGINE = SummingMergeTree
PRIMARY KEY (user_id, project)
ORDER BY (user_id, project)
SETTINGS index_granularity = 8192;

CREATE TABLE heartbeat_project_dimension_daily_stats
(
    `user_id` UInt32 CODEC(T64, ZSTD(1)),
    `project` LowCardinality(String) CODEC(ZSTD(1)),
    `dimension` LowCardinality(String) CODEC(ZSTD(1)),
    `value` String CODEC(ZSTD(3)),
    `day` Date CODEC(Delta(2), ZSTD(1)),
    `seconds` Float64 CODEC(Gorilla(8), ZSTD(1)),
    `first_seconds` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `heartbeat_count` Int64 CODEC(T64, ZSTD(1))
)
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(day)
PRIMARY KEY (user_id, project, dimension, value, day)
ORDER BY (user_id, project, dimension, value, day)
SETTINGS index_granularity = 8192;

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

CREATE TABLE heartbeat_dimension_attribution_daily_stats
(
    `user_id` UInt32 CODEC(T64, ZSTD(1)),
    `dimension` LowCardinality(String) CODEC(ZSTD(1)),
    `value` String CODEC(ZSTD(3)),
    `day` Date CODEC(Delta(2), ZSTD(1)),
    `seconds` Float64 CODEC(Gorilla(8), ZSTD(1)),
    `first_seconds` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `heartbeat_count` Int64 CODEC(T64, ZSTD(1))
)
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(day)
PRIMARY KEY (user_id, dimension, value, day)
ORDER BY (user_id, dimension, value, day)
SETTINGS index_granularity = 8192;

CREATE TABLE heartbeat_project_daily_stats
(
    `user_id` UInt32 CODEC(T64, ZSTD(1)),
    `project` LowCardinality(String) CODEC(ZSTD(1)),
    `day` Date CODEC(Delta(2), ZSTD(1)),
    `seconds` Float64 CODEC(Gorilla(8), ZSTD(1)),
    `first_seconds` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `heartbeat_count` Int64 CODEC(T64, ZSTD(1))
)
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(day)
PRIMARY KEY (user_id, project, day)
ORDER BY (user_id, project, day)
SETTINGS index_granularity = 8192;

CREATE TABLE heartbeat_dimension_daily_stats
(
    `user_id` UInt32 CODEC(T64, ZSTD(1)),
    `dimension` LowCardinality(String) CODEC(ZSTD(1)),
    `value` String CODEC(ZSTD(3)),
    `day` Date CODEC(Delta(2), ZSTD(1)),
    `seconds` Float64 CODEC(Gorilla(8), ZSTD(1)),
    `first_seconds` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `heartbeat_count` Int64 CODEC(T64, ZSTD(1))
)
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(day)
PRIMARY KEY (user_id, dimension, value, day)
ORDER BY (user_id, dimension, value, day)
SETTINGS index_granularity = 8192;

CREATE TABLE heartbeat_interval_deltas
(
    `delta_id` UInt64 CODEC(Delta(8), LZ4),
    `user_id` UInt32 CODEC(T64, ZSTD(1)),
    `day` Date CODEC(Delta(2), ZSTD(1)),
    `time` Float64 CODEC(Gorilla(8), ZSTD(1)),
    `project` LowCardinality(String) CODEC(ZSTD(1)),
    `language` LowCardinality(String) CODEC(ZSTD(1)),
    `editor` LowCardinality(String) CODEC(ZSTD(1)),
    `operating_system` LowCardinality(String) CODEC(ZSTD(1)),
    `machine` LowCardinality(String) DEFAULT '' CODEC(ZSTD(1)),
    `category` LowCardinality(String) CODEC(ZSTD(1)),
    `entity` String CODEC(ZSTD(3)),
    `branch` String CODEC(ZSTD(3)),
    `user_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `user_first_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `project_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `project_first_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `language_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `language_first_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `editor_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `editor_first_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `operating_system_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `operating_system_first_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `machine_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `machine_first_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `category_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `category_first_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `entity_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `entity_first_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `branch_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `branch_first_seconds_delta` Float64 DEFAULT 0 CODEC(Gorilla(8), ZSTD(1)),
    `heartbeat_count_delta` Int64 CODEC(T64, ZSTD(1)),
    `reason` LowCardinality(String) CODEC(ZSTD(1)),
    `created_at` DateTime64(6, 'UTC') CODEC(Delta(8), ZSTD(1))
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(day)
PRIMARY KEY (user_id, day)
ORDER BY (user_id, day, time, delta_id)
SETTINGS index_granularity = 8192;

CREATE MATERIALIZED VIEW mv_heartbeat_user_daily_stats TO heartbeat_user_daily_stats
(
    `user_id` UInt32,
    `day` Date,
    `seconds` Int64,
    `first_seconds` Int64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    day,
    sum(user_seconds_delta) AS seconds,
    sum(user_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
GROUP BY
    user_id,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_project_summaries TO heartbeat_project_summaries
(
    `user_id` UInt32,
    `project` LowCardinality(String),
    `seconds` Int64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    project,
    sum(project_seconds_delta) AS seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE project != ''
GROUP BY
    user_id,
    project;

CREATE MATERIALIZED VIEW mv_heartbeat_project_operating_system_daily_stats TO heartbeat_project_dimension_daily_stats
(
    `user_id` UInt32,
    `project` LowCardinality(String),
    `dimension` String,
    `value` LowCardinality(String),
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    project,
    'operating_system' AS dimension,
    operating_system AS value,
    day,
    sum(project_seconds_delta) AS seconds,
    sum(project_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE (project != '') AND (operating_system NOT IN ('', '__HACKATIME_NULL_DIMENSION_7F3D8C2A__'))
GROUP BY
    user_id,
    project,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_project_language_daily_stats TO heartbeat_project_dimension_daily_stats
(
    `user_id` UInt32,
    `project` LowCardinality(String),
    `dimension` String,
    `value` LowCardinality(String),
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    project,
    'language' AS dimension,
    language AS value,
    day,
    sum(project_seconds_delta) AS seconds,
    sum(project_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE (project != '') AND (language NOT IN ('', '__HACKATIME_NULL_DIMENSION_7F3D8C2A__'))
GROUP BY
    user_id,
    project,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_project_entity_daily_stats TO heartbeat_project_dimension_daily_stats
(
    `user_id` UInt32,
    `project` LowCardinality(String),
    `dimension` String,
    `value` String,
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    project,
    'entity' AS dimension,
    entity AS value,
    day,
    sum(project_seconds_delta) AS seconds,
    sum(project_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE (project != '') AND (entity != '__HACKATIME_NULL_DIMENSION_7F3D8C2A__')
GROUP BY
    user_id,
    project,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_project_editor_daily_stats TO heartbeat_project_dimension_daily_stats
(
    `user_id` UInt32,
    `project` LowCardinality(String),
    `dimension` String,
    `value` LowCardinality(String),
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    project,
    'editor' AS dimension,
    editor AS value,
    day,
    sum(project_seconds_delta) AS seconds,
    sum(project_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE (project != '') AND (editor NOT IN ('', '__HACKATIME_NULL_DIMENSION_7F3D8C2A__'))
GROUP BY
    user_id,
    project,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_project_daily_stats TO heartbeat_project_daily_stats
(
    `user_id` UInt32,
    `project` LowCardinality(String),
    `day` Date,
    `seconds` Int64,
    `first_seconds` Int64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    project,
    day,
    sum(project_seconds_delta) AS seconds,
    sum(project_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE project != ''
GROUP BY
    user_id,
    project,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_project_category_daily_stats TO heartbeat_project_dimension_daily_stats
(
    `user_id` UInt32,
    `project` LowCardinality(String),
    `dimension` String,
    `value` LowCardinality(String),
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    project,
    'category' AS dimension,
    category AS value,
    day,
    sum(project_seconds_delta) AS seconds,
    sum(project_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE (project != '') AND (category NOT IN ('', '__HACKATIME_NULL_DIMENSION_7F3D8C2A__'))
GROUP BY
    user_id,
    project,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_project_branch_daily_stats TO heartbeat_project_dimension_daily_stats
(
    `user_id` UInt32,
    `project` LowCardinality(String),
    `dimension` String,
    `value` String,
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    project,
    'branch' AS dimension,
    branch AS value,
    day,
    sum(project_seconds_delta) AS seconds,
    sum(project_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE (project != '') AND (branch NOT IN ('', '__HACKATIME_NULL_DIMENSION_7F3D8C2A__'))
GROUP BY
    user_id,
    project,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_operating_system_daily_stats TO heartbeat_dimension_daily_stats
(
    `user_id` UInt32,
    `dimension` String,
    `value` LowCardinality(String),
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    'operating_system' AS dimension,
    operating_system AS value,
    day,
    sum(operating_system_seconds_delta) AS seconds,
    sum(operating_system_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
GROUP BY
    user_id,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_operating_system_attribution_daily_stats TO heartbeat_dimension_attribution_daily_stats
(
    `user_id` UInt32,
    `dimension` String,
    `value` LowCardinality(String),
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    'operating_system' AS dimension,
    operating_system AS value,
    day,
    sum(user_seconds_delta) AS seconds,
    sum(user_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE operating_system NOT IN ('', '__HACKATIME_NULL_DIMENSION_7F3D8C2A__')
GROUP BY
    user_id,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_machine_daily_stats TO heartbeat_dimension_daily_stats
(
    `user_id` UInt32,
    `dimension` String,
    `value` LowCardinality(String),
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    'machine' AS dimension,
    machine AS value,
    day,
    sum(machine_seconds_delta) AS seconds,
    sum(machine_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
GROUP BY
    user_id,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_machine_attribution_daily_stats TO heartbeat_dimension_attribution_daily_stats
(
    `user_id` UInt32,
    `dimension` String,
    `value` LowCardinality(String),
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    'machine' AS dimension,
    machine AS value,
    day,
    sum(user_seconds_delta) AS seconds,
    sum(user_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE machine NOT IN ('', '__HACKATIME_NULL_DIMENSION_7F3D8C2A__')
GROUP BY
    user_id,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_language_daily_stats TO heartbeat_dimension_daily_stats
(
    `user_id` UInt32,
    `dimension` String,
    `value` LowCardinality(String),
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    'language' AS dimension,
    language AS value,
    day,
    sum(language_seconds_delta) AS seconds,
    sum(language_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
GROUP BY
    user_id,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_language_attribution_daily_stats TO heartbeat_dimension_attribution_daily_stats
(
    `user_id` UInt32,
    `dimension` String,
    `value` LowCardinality(String),
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    'language' AS dimension,
    language AS value,
    day,
    sum(user_seconds_delta) AS seconds,
    sum(user_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE language NOT IN ('', '__HACKATIME_NULL_DIMENSION_7F3D8C2A__')
GROUP BY
    user_id,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_entity_daily_stats TO heartbeat_dimension_daily_stats
(
    `user_id` UInt32,
    `dimension` String,
    `value` String,
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    'entity' AS dimension,
    entity AS value,
    day,
    sum(entity_seconds_delta) AS seconds,
    sum(entity_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
GROUP BY
    user_id,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_entity_attribution_daily_stats TO heartbeat_dimension_attribution_daily_stats
(
    `user_id` UInt32,
    `dimension` String,
    `value` String,
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    'entity' AS dimension,
    entity AS value,
    day,
    sum(user_seconds_delta) AS seconds,
    sum(user_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE entity NOT IN ('', '__HACKATIME_NULL_DIMENSION_7F3D8C2A__')
GROUP BY
    user_id,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_editor_daily_stats TO heartbeat_dimension_daily_stats
(
    `user_id` UInt32,
    `dimension` String,
    `value` LowCardinality(String),
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    'editor' AS dimension,
    editor AS value,
    day,
    sum(editor_seconds_delta) AS seconds,
    sum(editor_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
GROUP BY
    user_id,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_editor_attribution_daily_stats TO heartbeat_dimension_attribution_daily_stats
(
    `user_id` UInt32,
    `dimension` String,
    `value` LowCardinality(String),
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    'editor' AS dimension,
    editor AS value,
    day,
    sum(user_seconds_delta) AS seconds,
    sum(user_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE editor NOT IN ('', '__HACKATIME_NULL_DIMENSION_7F3D8C2A__')
GROUP BY
    user_id,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_category_daily_stats TO heartbeat_dimension_daily_stats
(
    `user_id` UInt32,
    `dimension` String,
    `value` LowCardinality(String),
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    'category' AS dimension,
    category AS value,
    day,
    sum(category_seconds_delta) AS seconds,
    sum(category_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
GROUP BY
    user_id,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_category_attribution_daily_stats TO heartbeat_dimension_attribution_daily_stats
(
    `user_id` UInt32,
    `dimension` String,
    `value` LowCardinality(String),
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    'category' AS dimension,
    category AS value,
    day,
    sum(user_seconds_delta) AS seconds,
    sum(user_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE category NOT IN ('', '__HACKATIME_NULL_DIMENSION_7F3D8C2A__')
GROUP BY
    user_id,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_branch_daily_stats TO heartbeat_dimension_daily_stats
(
    `user_id` UInt32,
    `dimension` String,
    `value` String,
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    'branch' AS dimension,
    branch AS value,
    day,
    sum(branch_seconds_delta) AS seconds,
    sum(branch_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
GROUP BY
    user_id,
    dimension,
    value,
    day;

CREATE MATERIALIZED VIEW mv_heartbeat_branch_attribution_daily_stats TO heartbeat_dimension_attribution_daily_stats
(
    `user_id` UInt32,
    `dimension` String,
    `value` String,
    `day` Date,
    `seconds` Float64,
    `first_seconds` Float64,
    `heartbeat_count` Int64
)
AS SELECT
    user_id,
    'branch' AS dimension,
    branch AS value,
    day,
    sum(user_seconds_delta) AS seconds,
    sum(user_first_seconds_delta) AS first_seconds,
    sum(heartbeat_count_delta) AS heartbeat_count
FROM heartbeat_interval_deltas
WHERE branch NOT IN ('', '__HACKATIME_NULL_DIMENSION_7F3D8C2A__')
GROUP BY
    user_id,
    dimension,
    value,
    day;

INSERT INTO schema_migrations (version) VALUES
('20260711210015'),
('20260711180148'),
('20260711175705'),
('20260710000006'),
('20260710000005'),
('20260710000004'),
('20260710000003'),
('20260710000002'),
('20260710000001'),
('20260709000001'),
('20260708000001'),
('20260706000001');

