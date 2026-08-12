# ClickHouse heartbeat cutover

Hackatime stores heartbeat data only in ClickHouse after cutover. PostgreSQL keeps relational product data, monotonic heartbeat ID/version sequences, advisory locks and coarse transfer, deletion and JA4 workflow status. The supported server is ClickHouse OSS `26.7.3.19`.

`HEARTBEAT_STORE` deliberately defaults to `postgresql`, so merging this release cannot switch an unprovisioned production environment. The only accepted values are `postgresql` and `clickhouse`; an invalid value fails instead of silently selecting a store. Set it explicitly and identically on every web and worker process. Keep `postgresql` through provisioning, migration and backfill, then set `clickhouse` only at the fenced cutover. Every direct and imported PostgreSQL ingest insert transaction takes a shared lock and rechecks the durable cutover row. Ingests remain concurrent with one another, while purge's exclusive lock waits for all in-flight inserts. After PostgreSQL payload purge is recorded, even a request admitted by a stale process before the fence changed is refused at insert time rather than repopulating the empty legacy table.

## Provisioning

Provision one ClickHouse server with persistent storage, TLS and a least-privilege application account. Back it up to storage outside that server and test the restore runbook before cutover. Heartbeat-backed features are unavailable while the server is down, so monitor disk health, backup freshness and restore readiness. Replication can be added later if that availability trade-off changes, but it is not part of this deployment.

Before cutover, set and load-test per-query and per-user memory, concurrency and execution-time limits for the server's available RAM. Configure external sort and group-by spill thresholds, disk free-space and MergeTree part alerts and a tested off-node backup schedule. Record the accepted RPO and RTO: lifecycle controls can be replayed after a stale restore, but ordinary heartbeats newer than the restored backup cannot be recreated from PostgreSQL.

The Ruby client controls the JSON compatibility settings required by this schema: numbers encoded as strings are accepted on input and 64-bit integers/floats are emitted as JSON numbers. The exact server build is a compatibility gate, not an instruction to ignore security releases. For an upgrade, restore a recent backup into an isolated candidate server, change the pinned image and version guard together, run `clickhouse:migrate`, the real ClickHouse integration/differential/concurrency/task test leg and a production-sized read/write benchmark, then perform a canary restore and rollback drill before replacing production. Do not bypass the version guard on an untested build.

Development and test use separate `hackatime_development` and `hackatime_test` databases. GitHub's `test_clickhouse` job starts the pinned server with an explicit CI-only password, applies the ClickHouse schema and runs the API ingestion, integration, differential, concurrency and task suites with `CLICKHOUSE_INTEGRATION=1`, `CLICKHOUSE_REQUIRED=1` and `CLICKHOUSE_TEST=1`. A gated suite fails instead of skipping when ClickHouse is required. The deploy job depends on this job; repository branch protection must separately make it a required merge check.

### Coolify deployment layout

Run ClickHouse as a separate Coolify service, not inside either Rails application. Pin the image to `clickhouse/clickhouse-server:26.7.3.19`, mount persistent storage at `/var/lib/clickhouse` and keep ports 8123/9000 private to the Coolify network. Give Rails a least-privilege user and a URL such as `http://hackatime-clickhouse:8123/hackatime`; use TLS if traffic leaves the private host/network. Do not expose the default user or either native port publicly.

On a machine with about 192 GiB RAM, start conservatively: reserve at least 32 GiB for the kernel/filesystem cache and other services, cap ClickHouse below the remainder, then load-test before increasing it. Configure per-query/per-user memory and concurrency, `max_execution_time`, external sort/group-by spill thresholds and disk/part alerts in the ClickHouse user profile. Repository defaults do not replace production quotas. Keep web and worker as separate Coolify applications with the same `CLICKHOUSE_URL`, `HEARTBEAT_STORE` and fence values.

Create an off-node backup schedule before backfill. Alert on backup age and failure, retain PostgreSQL lifecycle controls at least as long as the oldest restorable ClickHouse backup and complete one restore plus `clickhouse:replay_lifecycle_controls` drill. Record the ordinary-heartbeat RPO, expected restore time and how long Rails remains unavailable during recovery.

The schema has four authoritative objects:

- `heartbeat_store` keeps immutable candidate payloads, canonical lifecycle state and independent delivery acknowledgements.
- `heartbeat_aliases` maps canonical and legacy hashes to active heartbeat IDs.
- `heartbeats` is the user-first query layout.
- `heartbeats_by_time` is the time-first query layout.

`fields_hash` is stored only in the canonical store and alias index. It is user-independent because the alias primary key already includes the user; this lets account transfers deduplicate without changing the query payload. Historical user-specific and import hashes remain ClickHouse aliases. The accepted-ingest API still returns the request-compatible identity hash. The hash is not a query-table column or sorting key. PostgreSQL advisory locks serialize admission for one user but do not persist heartbeat data. Materialized views are not part of the delivery correctness boundary.

All four tables use non-replicated `ReplacingMergeTree` engines. A bounded local deduplication log makes retries of one allocated insert block idempotent without ClickHouse Keeper. New ingestion reserves its allocated ID in the alias index before writing the canonical payload. If the payload response is lost, a request retry reconstructs any missing payload at that reserved ID rather than allocating a second canonical identity. Canonical versions and delivery acknowledgements remain the recovery boundary if an insert's outcome stays unknown after all retries.

Apply relational and ClickHouse migrations from one release process:

```sh
HEARTBEAT_STORE=postgresql bin/rails db:migrate
HEARTBEAT_STORE=postgresql bin/rake clickhouse:migrate
```

In Coolify, first deploy this release to web and worker with `HEARTBEAT_STORE=postgresql` and both fence values `0`. Run the two migration commands once from a one-off terminal/release command. Confirm `SELECT version()` returns the pinned build and that all four tables exist before starting backfill. An “Unknown ClickHouse migrations” error must be investigated; only an explicitly disposable pre-cutover database may be reset.

## Online backfill

First finish every recorded transfer, account deletion and JA4 nullification. Then set `HEARTBEAT_MUTATIONS_STOPPED=1` on every web and worker process. This fence blocks individual heartbeat delete/restore, account merge/deletion and JA4 deletion at both admission and job execution, while direct and imported heartbeat ingestion continues in PostgreSQL.

The first pass records an upper ID boundary and durable progress in `heartbeat_cutovers`:

```sh
HEARTBEAT_STORE=postgresql HEARTBEAT_MUTATIONS_STOPPED=1 \
  bin/rake clickhouse:backfill
```

The repository groups every payload insert by destination month before applying its 10,000-row cap. This keeps historical backfill, transfer, deletion and repair below ClickHouse's partition-per-insert limit rather than raising the server safety limit. Verification reads PostgreSQL rows in ID order but looks up ClickHouse rows by each layout's full sorting-key tuple, so it does not repeatedly scan a bare global ID range.

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

The purge drains delivery and reruns payload, alias and query-layout verification before truncating PostgreSQL heartbeat payloads and dashboard rollups. Its final PostgreSQL transaction locks the cutover row, rechecks that the source boundary has not advanced, records `purged_at`, truncates both payload tables and resets rollup generations atomically. A request that acquired the lock first either makes the boundary check abort the purge or is included in an earlier verified boundary; a request that acquires it after purge is refused. An interruption rolls the entire purge back. It intentionally leaves the now-empty tables represented in Rails schema history; remove them with an explicit Rails migration in a later release after the operational rollback window expires. Do not reopen either fence if canonical rows, aliases, delivery acknowledgements or either query layout disagree. Only after purge succeeds should the release set both fence variables back to `0` and reopen traffic.

This is the irreversible commit point. There is no observation window in which ClickHouse accepts new heartbeats and PostgreSQL remains a lossless rollback target: new ClickHouse rows are intentionally not copied back to PostgreSQL. Before purge, rollback means keeping both fences enabled and switching reads back to the still-complete PostgreSQL table. After purge, rollback means restoring ClickHouse. ClickHouse-mode dashboard, profile and homepage reads use exact ClickHouse queries and do not rebuild PostgreSQL rollups. Initial ClickHouse dashboard data is deferred and expensive repeated global/profile/streak reads retain short application-cache boundaries.

The final write fence is the only ingestion interruption. Keep the online backfill phase unfenced for ordinary writes, schedule the final fence for a low-traffic window and rely on normal client retries for rejected heartbeats. In Coolify, apply stricter fence values before switching the store; never temporarily reopen a fence on one application. Verify the environment reported by both web and worker containers before running the final backfill. Reopen both only after purge and smoke checks.

Account deletion applies ClickHouse tombstones synchronously before relational anonymisation can succeed, with the durable job retained for retry. Account merge commits its durable transfer control with the relational merge and the queued idempotent transfer then moves the heartbeats. While that transfer is pending, both source and surviving target accounts reject heartbeat writes so admission cannot race the two-user move. The surviving account may temporarily omit the transferred activity and global source activity can remain visible. After completion, only the retired source remains permanently blocked. This bounded asynchronous merge behavior is not used for account deletion, where privacy requires synchronous tombstones.

ClickHouse requests made while PostgreSQL admission locks are held use deliberately short budgets: ordinary ingest makes one attempt with a two-second per-request network timeout and a ten-second aggregate monotonic deadline for the admission transaction, while lifecycle mutations make at most two attempts with five-second network timeouts. ClickHouse imports are divided into at most 1,000 records per admission transaction, releasing the PostgreSQL connection and user lock between chunks. A partially completed import remains safe to retry because canonical identity and insert tokens are stable, while the delivery job repairs incomplete layouts. These budgets bound PostgreSQL connection pressure during ClickHouse degradation; tune application concurrency and ClickHouse quotas against this failure mode before cutover.

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

After restoring a ClickHouse backup, keep web traffic unavailable and set both write fences to `1` on every process. PostgreSQL lifecycle rows must be retained for at least as long as the oldest recoverable ClickHouse backup. Account transfers, account deletions and JA4 nullifications are replayable because they have durable PostgreSQL controls. Individual heartbeat delete/restore actions do not have equivalent PostgreSQL controls; restoring a backup from before one of those actions can undo it. Those actions, like newly ingested heartbeat payloads, are therefore inside the accepted ClickHouse backup RPO. The recovery task first advances the PostgreSQL heartbeat ID and version sequences past every value in the restored canonical store, alias index and retained lifecycle controls. This prevents an older PostgreSQL restore from reusing ClickHouse IDs or versions.

The task then takes a stable snapshot of the lifecycle rows, rejects unfinished controls and conservatively replays every retained transfer, account deletion and JA4 nullification in causal order. Only the recovery process temporarily bypasses its local mutation fence; web and worker processes remain fenced. Finally it repairs both query layouts and verifies deleted users, JA4 removal and delivery acknowledgements:

```sh
HEARTBEAT_STORE=clickhouse HEARTBEAT_WRITES_STOPPED=1 HEARTBEAT_MUTATIONS_STOPPED=1 \
  bin/rake clickhouse:replay_lifecycle_controls
```

Do not set `TABLE`, `PARTITION`, `AFTER_USER_ID` or `AFTER_ID` for recovery. The sequence-only step can be rerun independently with `clickhouse:reseed_postgres_sequences` under both fences. Review the completed verification output before reopening reads or accepting writes.

After PostgreSQL purge, rollback means restoring or rebuilding ClickHouse from its canonical store and backups. There is intentionally no PostgreSQL heartbeat restore path.
