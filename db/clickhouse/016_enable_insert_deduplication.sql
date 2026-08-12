ALTER TABLE heartbeats
MODIFY SETTING non_replicated_deduplication_window = 10000;

ALTER TABLE heartbeats_by_time
MODIFY SETTING non_replicated_deduplication_window = 10000;

ALTER TABLE heartbeat_store
MODIFY SETTING non_replicated_deduplication_window = 10000;

ALTER TABLE heartbeat_aliases
MODIFY SETTING non_replicated_deduplication_window = 10000
