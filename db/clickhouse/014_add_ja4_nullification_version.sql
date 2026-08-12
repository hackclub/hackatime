ALTER TABLE heartbeat_store
ADD COLUMN IF NOT EXISTS ja4_nullification_version UInt64 DEFAULT 0 CODEC(T64, ZSTD(1)) AFTER duplicate_of
