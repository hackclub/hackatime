# ClickHouse heartbeat cutover

Hackatime stores heartbeat data only in ClickHouse after cutover. PostgreSQL keeps relational product data, monotonic heartbeat ID/version sequences, advisory locks and coarse transfer, deletion and JA4 workflow status. The supported server is ClickHouse OSS `26.7.3.19`, the latest 26.7 patch release.

`HEARTBEAT_STORE` defaults to `clickhouse`. Set it identically on web and worker processes and use `postgresql` explicitly only for the backfill phase.

## Provisioning

Provision one ClickHouse server with persistent storage, TLS and a least-privilege application account. Back it up to storage outside that server and test the restore runbook before cutover. Heartbeat-backed features are unavailable while the server is down, so monitor disk health, backup freshness and restore readiness. Replication can be added later if that availability trade-off changes, but it is not part of this deployment.

Before cutover, set and load-test per-query and per-user memory, concurrency and execution-time limits for the server's available RAM. Configure external sort and group-by spill thresholds, disk free-space and MergeTree part alerts and a tested off-node backup schedule. Record the accepted RPO and RTO: lifecycle controls can be replayed after a stale restore, but ordinary heartbeats newer than the restored backup cannot be recreated from PostgreSQL.

The schema has four authoritative objects:

- `heartbeat_store` keeps immutable candidate payloads, canonical lifecycle state and independent delivery acknowledgements.
- `heartbeat_aliases` maps canonical and legacy hashes to active heartbeat IDs.
- `heartbeats` is the user-first query layout.
- `heartbeats_by_time` is the time-first query layout.

`fields_hash` belongs only to the canonical store and alias index. It is user-independent because the alias primary key already includes the user; this lets account transfers deduplicate without changing the query payload. Historical user-specific and import hashes remain ClickHouse aliases. The hash is not a query-table column or sorting key. PostgreSQL advisory locks serialize admission for one user but do not persist heartbeat data. Materialized views are not part of the delivery correctness boundary.

All four tables use non-replicated `ReplacingMergeTree` engines. A bounded local deduplication log makes synchronous retries with stable insert tokens idempotent without ClickHouse Keeper. Canonical versions and delivery acknowledgements remain the recovery boundary if an insert's outcome stays unknown after all retries.

Apply relational and ClickHouse migrations from one release process:

```sh
HEARTBEAT_STORE=postgresql bin/rails db:migrate
HEARTBEAT_STORE=postgresql bin/rake clickhouse:migrate
```

## Online backfill

First finish every recorded transfer, account deletion and JA4 nullification. Then set `HEARTBEAT_MUTATIONS_STOPPED=1` on every web and worker process. This fence blocks individual heartbeat delete/restore, account merge/deletion and JA4 deletion at both admission and job execution, while direct and imported heartbeat ingestion continues in PostgreSQL.

The first pass records an upper ID boundary and durable progress in `heartbeat_cutovers`:

```sh
HEARTBEAT_STORE=postgresql HEARTBEAT_MUTATIONS_STOPPED=1 \
  bin/rake clickhouse:backfill
```

Keep the mutation fence enabled through purge. PostgreSQL can continue accepting append-only heartbeats during the first pass because the final pass captures IDs above the first boundary. The task rejects an incomplete lifecycle queue, so do not set the fence until existing controls have completed.

## Write-fenced cutover

Also set `HEARTBEAT_WRITES_STOPPED=1` on every web and worker process. The application now rejects direct and imported heartbeat writes as well as every mutation. Backfill extends the recorded boundary to the fenced PostgreSQL maximum and resumes from its durable cursor:

```sh
HEARTBEAT_STORE=postgresql HEARTBEAT_WRITES_STOPPED=1 HEARTBEAT_MUTATIONS_STOPPED=1 \
  bin/rake clickhouse:backfill
HEARTBEAT_STORE=postgresql HEARTBEAT_WRITES_STOPPED=1 HEARTBEAT_MUTATIONS_STOPPED=1 \
  bin/rake clickhouse:drain_outbox
HEARTBEAT_STORE=postgresql HEARTBEAT_WRITES_STOPPED=1 HEARTBEAT_MUTATIONS_STOPPED=1 \
  bin/rake clickhouse:verify
```

Switch every process to `HEARTBEAT_STORE=clickhouse` together. Run read checks while both fences remain enabled, then permanently remove PostgreSQL heartbeat storage:

```sh
HEARTBEAT_STORE=clickhouse HEARTBEAT_WRITES_STOPPED=1 HEARTBEAT_MUTATIONS_STOPPED=1 \
  bin/rake clickhouse:purge_postgres
```

The purge drains delivery and reruns payload, alias and query-layout verification before dropping PostgreSQL heartbeat storage. Do not reopen either fence if canonical rows, aliases, delivery acknowledgements or either query layout disagree. Only after purge succeeds should the release set both fence variables back to `0` and reopen traffic.

This is the irreversible commit point. There is no observation window in which ClickHouse accepts new heartbeats and PostgreSQL remains a lossless rollback target: new ClickHouse rows are intentionally not copied back to PostgreSQL. Before purge, rollback means keeping both fences enabled and switching reads back to the still-complete PostgreSQL table. After purge, rollback means restoring ClickHouse. The purge also drops PostgreSQL dashboard rollup storage. ClickHouse-mode dashboard, profile and homepage reads use exact ClickHouse queries and do not rebuild those rollups.

## Recovery

Failed writes enqueue `HeartbeatDeliveryJob` for the affected user, which repairs pending candidates and independently retries both query layouts without scanning unrelated history. One serial global audit runs daily as a backstop. Account transfer keeps permanent source-key tombstones so a delayed stale insert cannot reactivate the old owner. Repair missing query rows entirely from ClickHouse with:

```sh
HEARTBEAT_STORE=clickhouse bin/rake clickhouse:repair_query_layouts
HEARTBEAT_STORE=clickhouse bin/rake clickhouse:drain_outbox
```

The repair task processes one canonical store month and at most 10,000 rows at a time. To resume a stopped repair, use the last progress line:

```sh
HEARTBEAT_STORE=clickhouse TABLE=heartbeats_by_time PARTITION=202608 \
  AFTER_USER_ID=123 AFTER_ID=456 bin/rake clickhouse:repair_query_layouts
```

After restoring a ClickHouse backup, keep web traffic unavailable and set both write fences to `1` on every process. PostgreSQL lifecycle rows must be retained for at least as long as the oldest recoverable ClickHouse backup. The recovery task first advances the PostgreSQL heartbeat ID and version sequences past every value in the restored canonical store, alias index and retained lifecycle controls. This prevents an older PostgreSQL restore from reusing ClickHouse IDs or versions.

The task then takes a stable snapshot of the lifecycle rows, rejects unfinished controls and conservatively replays every retained transfer, account deletion and JA4 nullification in causal order. Only the recovery process temporarily bypasses its local mutation fence; web and worker processes remain fenced. Finally it repairs both query layouts and verifies deleted users, JA4 removal and delivery acknowledgements:

```sh
HEARTBEAT_STORE=clickhouse HEARTBEAT_WRITES_STOPPED=1 HEARTBEAT_MUTATIONS_STOPPED=1 \
  bin/rake clickhouse:replay_lifecycle_controls
```

Do not set `TABLE`, `PARTITION`, `AFTER_USER_ID` or `AFTER_ID` for recovery. The sequence-only step can be rerun independently with `clickhouse:reseed_postgres_sequences` under both fences. Review the completed verification output before reopening reads or accepting writes.

After PostgreSQL purge, rollback means restoring or rebuilding ClickHouse from its canonical store and backups. There is intentionally no PostgreSQL heartbeat restore path.
