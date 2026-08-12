# ClickHouse heartbeat cutover

Hackatime stores heartbeat data only in ClickHouse after cutover. PostgreSQL keeps relational product data, monotonic heartbeat ID/version sequences, advisory locks and coarse transfer, deletion and JA4 workflow status. The supported server is ClickHouse OSS `26.7.3.19`, the latest 26.7 patch release.

`HEARTBEAT_STORE` defaults to `clickhouse`. Set it identically on web and worker processes and use `postgresql` explicitly only for the backfill phase.

## Provisioning

Provision one ClickHouse server with persistent storage, TLS and a least-privilege application account. Back it up to storage outside that server and test the restore runbook before cutover. Heartbeat-backed features are unavailable while the server is down, so monitor disk health, backup freshness and restore readiness. Replication can be added later if that availability trade-off changes, but it is not part of this deployment.

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

The first pass records an upper ID boundary and durable progress in `heartbeat_cutovers`:

```sh
HEARTBEAT_STORE=postgresql bin/rake clickhouse:backfill
```

Keep individual heartbeat mutation, account merge, account deletion and JA4 deletion unavailable until cutover. PostgreSQL can continue accepting append-only heartbeats because the final pass captures IDs above the first boundary.

## Write-fenced cutover

Set `HEARTBEAT_WRITES_STOPPED=1` on every web and worker process. The application then rejects direct and imported heartbeat writes, individual delete and restore operations, account merge and deletion admission and JA4 deletion. Already recorded ClickHouse workflows continue to completion so verification can require an empty lifecycle queue. Backfill extends the recorded boundary to the fenced PostgreSQL maximum and resumes from its durable cursor:

```sh
HEARTBEAT_STORE=postgresql HEARTBEAT_WRITES_STOPPED=1 bin/rake clickhouse:backfill
HEARTBEAT_STORE=postgresql HEARTBEAT_WRITES_STOPPED=1 bin/rake clickhouse:drain_outbox
HEARTBEAT_STORE=postgresql HEARTBEAT_WRITES_STOPPED=1 bin/rake clickhouse:verify
```

Switch every process to `HEARTBEAT_STORE=clickhouse` together. Run focused ingestion and read checks while writes remain fenced. Once verified, permanently remove PostgreSQL heartbeat storage:

```sh
HEARTBEAT_STORE=clickhouse HEARTBEAT_WRITES_STOPPED=1 bin/rake clickhouse:purge_postgres
```

The purge drains delivery and reruns payload, alias and query-layout verification before dropping PostgreSQL heartbeat storage. Do not reopen writes if canonical rows, aliases, delivery acknowledgements or either query layout disagree. PostgreSQL must not receive a shadow heartbeat copy after this point. The purge also drops PostgreSQL dashboard rollup storage. ClickHouse-mode dashboard, profile and homepage reads use exact ClickHouse queries and do not rebuild those rollups.

## Recovery

Failed writes enqueue `HeartbeatDeliveryJob` for the affected user, which repairs pending candidates and independently retries both query layouts without scanning unrelated history. One serial global audit runs daily as a backstop. Account transfer keeps permanent source-key tombstones so a delayed stale insert cannot reactivate the old owner. Repair missing query rows entirely from ClickHouse with:

```sh
HEARTBEAT_STORE=clickhouse bin/rake clickhouse:repair_query_layouts
HEARTBEAT_STORE=clickhouse bin/rake clickhouse:drain_outbox
```

After PostgreSQL purge, rollback means restoring or rebuilding ClickHouse from its canonical store and backups. There is intentionally no PostgreSQL heartbeat restore path.
