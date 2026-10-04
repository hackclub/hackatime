-- Per-user dashboard rollup, derived from heartbeats and rebuilt by
-- DashboardRollupRefreshJob. One row per user, rebuild generation, local
-- hour (in the user's timezone at build time) and dashboard dimensions.
--
-- Each measure is a sum of capped heartbeat gaps (see Heartbeatable::DurationSql)
-- computed over a different window, so the dashboard can be summed from these
-- rows. Adding float partial sums can differ from one live sum by float error,
-- which only changes the rounded seconds in pathological cases. Measures:
--   duration              whole timeline (totals, languages, editors, rhythm)
--   project_duration      partitioned by project
--   day_duration          partitioned by local day (activity graph, today)
--   project_week_duration partitioned by project and local week
--
-- Readers only see the generation published in Postgres
-- (heartbeat_rollup_states), so a half-written rebuild is never visible.
-- Older generations are removed with lightweight deletes (patch parts).
CREATE TABLE IF NOT EXISTS heartbeat_rollups
(
    user_id UInt64,
    generation UInt64,
    local_date Date32,
    hour UInt8,
    project Nullable(String),
    language LowCardinality(Nullable(String)),
    editor LowCardinality(Nullable(String)),
    operating_system LowCardinality(Nullable(String)),
    category LowCardinality(Nullable(String)),
    heartbeats UInt64,
    duration Float64,
    project_duration Float64,
    day_duration Float64,
    project_week_duration Float64,
    first_time Float64,
    last_time Float64
)
ENGINE = MergeTree
ORDER BY (user_id, generation, local_date, hour)
SETTINGS enable_block_number_column = 1,
         enable_block_offset_column = 1
