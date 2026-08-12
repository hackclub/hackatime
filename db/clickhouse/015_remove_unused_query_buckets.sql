ALTER TABLE heartbeats
MODIFY COLUMN time_second Int64 MATERIALIZED toInt64(floor(ifNotFinite(time, 0)));

ALTER TABLE heartbeats
DROP COLUMN IF EXISTS time_epoch;

ALTER TABLE heartbeats
DROP COLUMN IF EXISTS time_hour;

ALTER TABLE heartbeats_by_time
MODIFY COLUMN time_second Int64 MATERIALIZED toInt64(floor(ifNotFinite(time, 0)));

ALTER TABLE heartbeats_by_time
DROP COLUMN IF EXISTS time_epoch;

ALTER TABLE heartbeats_by_time
DROP COLUMN IF EXISTS time_hour
