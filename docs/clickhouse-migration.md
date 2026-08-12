# Coolify ClickHouse heartbeat production runbook

This is the production operator runbook for moving Hackatime heartbeat payloads from PostgreSQL to a single ClickHouse server managed by Coolify. The migration is online except for a short final heartbeat write fence. The rest of Hackatime can remain available during that fence.

Hackatime stores heartbeat data only in ClickHouse after cutover. PostgreSQL continues to store relational product data, monotonic heartbeat ID/version sequences, advisory locks and durable account transfer, account deletion and JA4 nullification controls. The supported server is ClickHouse OSS `26.7.3.19`.

`HEARTBEAT_STORE` deliberately defaults to `postgresql`, so deploying this release cannot switch an unprovisioned production environment. The only accepted values are `postgresql` and `clickhouse`; a typo fails instead of silently selecting a store. Set it explicitly and identically on every web and worker process.

## Non-negotiable gates

Do not start cutover until all of these are true:

- ClickHouse data is on persistent NVMe storage and neither HTTP port 8123 nor native port 9000 is public.
- A least-privilege Rails account works from every web and worker resource.
- Production memory, concurrency, execution-time, spill, disk and parts guardrails are active.
- An off-node backup has completed and an isolated restore drill has passed.
- The ordinary-heartbeat RPO and the single-node RTO are explicitly accepted.
- The exact release's GitHub `test_clickhouse` job is green and required by branch protection.
- Web and worker use the same `CLICKHOUSE_URL`, `HEARTBEAT_STORE` and both fence values.
- The online backfill has completed before the final cutover window.
- The production-shaped read replay passes at the constrained memory profile without a user-facing latency regression.

This design is intentionally single-node and non-replicated. If losing one server cannot be allowed to interrupt heartbeat-backed features, do not cut over to this topology. Add and test a replicated design first. Backups protect durability, not availability.

## 1. Provision ClickHouse in Coolify

### Capacity plan for the current host

The Ryzen 9 7950X3D and approximately 188 GiB usable RAM are ample for a starting single node, but disk latency and free space matter more than peak CPU. PostgreSQL currently reserves 64 GiB in `shared_buffers`. The migration should reduce steady-state database memory, not merely add a generously capped ClickHouse process beside it.

ClickHouse does not preallocate its container or server limit, but those limits can still be reached under concurrent queries and merges. Use this staged **field starting budget**, then retain or change it only from production-shaped measurements:

| Phase | PostgreSQL `shared_buffers` | ClickHouse container | ClickHouse tracked server | Rails user total | Per query | Server query slots | Overflow wait |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Backfill and cutover | 64 GiB | 32 GiB | 24 GiB | 8 GiB | 1 GiB | 32 | 2 seconds |
| After purge and PostgreSQL retuning | 24 GiB target | 32 GiB | 24 GiB | 8 GiB | 1 GiB | 32 | 2 seconds |

The post-purge 24 GiB PostgreSQL value is a starting target, not a claim that the remaining relational workload needs exactly that amount. Measure the non-heartbeat working set and cache misses before applying it. The target PostgreSQL shared pool plus ClickHouse tracked ceiling is 48 GiB, below the current 64 GiB PostgreSQL shared pool alone. Actual total RAM also includes PostgreSQL backend-private memory, ClickHouse allocations not represented by query tracking and reclaimable filesystem cache, so judge the outcome from container/cgroup working set rather than adding only configuration values.

Keep 24 logical CPUs available to ClickHouse, throttle the online backfill instead of increasing memory under pressure and require enough NVMe space for the backfill, merges, a repair and at least 35% free space after cutover. Increase a limit only after the production-sized read replay described below proves that the limit, rather than query shape or disk, causes a material latency regression.

Measure the existing source and host before provisioning:

```sql
-- PostgreSQL
SELECT pg_size_pretty(pg_total_relation_size('heartbeats'));
```

```sh
# On the Coolify host. Use the actual path that backs Docker volumes.
df -h /var/lib/docker
```

The three ClickHouse payload tables intentionally duplicate query payloads, so do not size the volume from the PostgreSQL relation alone. Backfill a representative copy, measure `system.parts.bytes_on_disk` and extrapolate with operational headroom.

If the host is dedicated to ClickHouse, increase the limits only after a production-sized benchmark. Container memory includes more than query allocations, so never make the ClickHouse tracked-memory limit equal to the container hard limit.

### Create the Coolify service

In Coolify, open the production project and environment, select **Create New Resource**, then **Docker Compose Empty**. Use this Compose definition:

```yaml
services:
  clickhouse:
    image: clickhouse/clickhouse-server:26.7.3.19
    restart: unless-stopped
    stop_grace_period: 10m
    mem_limit: 32g
    cpus: "24.0"
    ulimits:
      nofile:
        soft: 262144
        hard: 262144
    environment:
      CLICKHOUSE_DB: hackatime
      CLICKHOUSE_USER: clickhouse_admin
      CLICKHOUSE_PASSWORD: ${SERVICE_PASSWORD_64_CLICKHOUSE_ADMIN}
      CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT: "1"
      CLICKHOUSE_BACKUP_S3_URL: ${CLICKHOUSE_BACKUP_S3_URL:?}
      CLICKHOUSE_BACKUP_S3_ACCESS_KEY: ${CLICKHOUSE_BACKUP_S3_ACCESS_KEY:?}
      CLICKHOUSE_BACKUP_S3_SECRET_KEY: ${CLICKHOUSE_BACKUP_S3_SECRET_KEY:?}
    volumes:
      - clickhouse_data:/var/lib/clickhouse
      - clickhouse_logs:/var/log/clickhouse-server
    configs:
      - source: clickhouse_server_config
        target: /etc/clickhouse-server/config.d/production.xml
      - source: clickhouse_admin_config
        target: /etc/clickhouse-server/users.d/zz-admin.xml
    expose:
      - "8123"
      - "9000"
      - "9363"
    healthcheck:
      test:
        - CMD-SHELL
        - >-
          clickhouse-client --user "$${CLICKHOUSE_USER}"
          --password "$${CLICKHOUSE_PASSWORD}" --query "SELECT 1"
      interval: 10s
      timeout: 5s
      retries: 12
      start_period: 30s

volumes:
  clickhouse_data:
  clickhouse_logs:

configs:
  clickhouse_server_config:
    content: |
      <clickhouse>
        <max_server_memory_usage>25769803776</max_server_memory_usage>
        <max_concurrent_queries>32</max_concurrent_queries>
        <concurrent_threads_soft_limit_num>48</concurrent_threads_soft_limit_num>
        <backups>
          <allow_concurrent_backups>false</allow_concurrent_backups>
          <allow_concurrent_restores>false</allow_concurrent_restores>
        </backups>
        <prometheus>
          <endpoint>/metrics</endpoint>
          <port>9363</port>
          <metrics>true</metrics>
          <events>true</events>
          <asynchronous_metrics>true</asynchronous_metrics>
        </prometheus>
        <named_collections>
          <hackatime_backups>
            <url from_env="CLICKHOUSE_BACKUP_S3_URL"/>
            <access_key_id from_env="CLICKHOUSE_BACKUP_S3_ACCESS_KEY"/>
            <secret_access_key from_env="CLICKHOUSE_BACKUP_S3_SECRET_KEY"/>
          </hackatime_backups>
        </named_collections>
      </clickhouse>
  clickhouse_admin_config:
    content: |
      <clickhouse>
        <profiles>
          <default>
            <queue_max_wait_ms>10000</queue_max_wait_ms>
          </default>
        </profiles>
        <users>
          <clickhouse_admin>
            <named_collection_control>1</named_collection_control>
          </clickhouse_admin>
        </users>
      </clickhouse>
```

Do **not** add `ports:` or a domain. Coolify leaves a Compose component internal when it has no published port or assigned domain. Review **Deployable Compose** before deploying and confirm the two named volumes remain attached. If using a dedicated NVMe mount, replace the data named volume with a host bind mount whose lifecycle is outside Coolify's application directory. Never delete the Coolify resource with its volumes selected.

Set these service secrets in Coolify before deployment:

- `SERVICE_PASSWORD_64_CLICKHOUSE_ADMIN`: let Coolify generate and retain it;
- `CLICKHOUSE_BACKUP_S3_URL`: an S3-compatible bucket base URL ending in a dedicated ClickHouse prefix and `/`;
- `CLICKHOUSE_BACKUP_S3_ACCESS_KEY` and `CLICKHOUSE_BACKUP_S3_SECRET_KEY`: write/read credentials limited to that backup prefix.

The backup bucket must be off this server. Enable bucket versioning or object immutability where available. Do not reuse the Rails application's broad object-storage credentials.

Deploy the service and wait for it to become healthy. In its Coolify terminal, verify:

```sh
clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" \
  --database hackatime --query "SELECT version(), currentDatabase()"
```

The version must be exactly `26.7.3.19` and the database must be `hackatime`.

### Connect Rails privately

The Rails applications and this service are separate Coolify resources. Enable **Connect to Predefined Network** for ClickHouse, web and worker, then inspect the deployable Compose to find ClickHouse's actual internal DNS name. Coolify may suffix it with the resource UUID; do not assume it is literally `clickhouse`.

Generate a URL-safe application password, keep it in the Coolify shared secrets and create the Rails user from the ClickHouse terminal:

```sh
openssl rand -hex 32
```

Replace `APP_PASSWORD` below without printing it into a shared log:

```sql
CREATE SETTINGS PROFILE IF NOT EXISTS hackatime_app_profile SETTINGS
    max_memory_usage = 1073741824 READONLY,
    max_memory_usage_for_user = 8589934592 READONLY,
    max_concurrent_queries_for_user = 64 READONLY,
    max_threads = 4 READONLY,
    queue_max_wait_ms = 2000 READONLY,
    max_execution_time = 60 READONLY,
    timeout_before_checking_execution_speed = 0 READONLY,
    max_bytes_before_external_group_by = 268435456 READONLY,
    max_bytes_before_external_sort = 268435456 READONLY;

CREATE USER IF NOT EXISTS hackatime_app
    IDENTIFIED WITH sha256_password BY 'APP_PASSWORD'
    SETTINGS PROFILE hackatime_app_profile;

GRANT SELECT, INSERT, ALTER TABLE, CREATE TABLE, DROP TABLE, SHOW TABLES, SHOW COLUMNS
    ON hackatime.* TO hackatime_app;

GRANT CREATE TEMPORARY TABLE ON *.* TO hackatime_app;
```

The application account deliberately has no global access management, backup or system-control privilege. The migration task needs table DDL because it creates schema reference tables to validate exact DDL.

Set this on **every** production web and worker resource, using the actual internal host and the generated hexadecimal password:

```text
CLICKHOUSE_URL=http://hackatime_app:APP_PASSWORD@CLICKHOUSE_INTERNAL_HOST:8123/hackatime
HEARTBEAT_STORE=postgresql
HEARTBEAT_WRITES_STOPPED=0
HEARTBEAT_MUTATIONS_STOPPED=0
```

Keep the URL private and never expose it in deployment output. If ClickHouse is on another host or traffic crosses an untrusted network, terminate TLS at ClickHouse or a private authenticated tunnel instead of using plain HTTP.

Deploy this application release to both web and worker in PostgreSQL mode. From each application's Coolify terminal, prove that its own environment can reach ClickHouse:

```sh
bin/rails runner 'puts ClickHouse::Client.current.select("SELECT version() AS version").sole.fetch("version")'
```

### Install and validate the schema

Run relational and ClickHouse migrations once from a Rails terminal or release command:

```sh
HEARTBEAT_STORE=postgresql bin/rails db:migrate
HEARTBEAT_STORE=postgresql bin/rake clickhouse:migrate
```

The migration task refuses a different ClickHouse build, unknown migration history and schema drift. Do not bypass those checks. Confirm the objects:

```sh
bin/rails runner 'pp ClickHouse::Client.current.select("SHOW TABLES")'
```

Expected application tables are `heartbeat_aliases`, `heartbeat_store`, `heartbeats`, `heartbeats_by_time` and `schema_migrations`.

The schema has four heartbeat objects:

- `heartbeat_store` keeps immutable candidate payloads, canonical lifecycle state and independent delivery acknowledgements.
- `heartbeat_aliases` maps canonical and legacy hashes to active heartbeat IDs.
- `heartbeats` is the user-first query layout.
- `heartbeats_by_time` is the time-first query layout.

`fields_hash` is stored only in the canonical store and alias index. It is user-independent because the alias primary key already includes the user; this lets account transfers deduplicate without changing the query payload. Historical user-specific and import hashes remain ClickHouse aliases. The accepted-ingest API still returns the request-compatible identity hash. The hash is not a query-table column or sorting key. PostgreSQL advisory locks serialize admission for one user but do not persist heartbeat data. Materialized views are not part of the delivery correctness boundary.

All four tables use non-replicated `ReplacingMergeTree` engines. A bounded local deduplication log makes retries of one allocated insert block idempotent without ClickHouse Keeper. New ingestion reserves its allocated ID in the alias index before writing the canonical payload. If the payload response is lost, a request retry reconstructs any missing payload at that reserved ID rather than allocating a second canonical identity. Canonical versions and delivery acknowledgements remain the recovery boundary if an insert's outcome stays unknown after all retries.

The Ruby client pins the JSON settings required by this schema, uses synchronous inserts and adds stable retry tokens. Do not enable `async_insert` in the server profile without re-running ambiguous-outcome and deduplication tests. Reads use `FINAL` for exact replacement state; monitor production query scan volume, memory and latency rather than assuming background merges remove that cost.

Development and test use separate `hackatime_development` and `hackatime_test` databases. GitHub's `test_clickhouse` job starts the pinned server with an explicit CI-only password and runs the API ingestion, integration, differential, concurrency and task suites with `CLICKHOUSE_REQUIRED=1`; a gated suite fails instead of skipping. The deploy job depends on this job, but repository branch protection must separately make it a required merge check.

### Establish the memory and latency baseline

Before backfill, retain at least seven representative days of:

- PostgreSQL, Rails and worker container/cgroup working set and peak memory;
- host available memory, swap activity and major page faults;
- user-facing p50, p95 and p99 latency for the heartbeat API, dashboard, profiles, homepage and leaderboards;
- PostgreSQL read latency, cache hit/miss counters, temporary-file bytes and top heartbeat query latency.

Also record `WEB_CONCURRENCY`, `RAILS_MAX_THREADS`, worker execution concurrency and the number of Coolify replicas. Web workers × Rails threads × web replicas bounds the web requests that can submit queries concurrently; excess requests wait or are rejected according to the proxy and application timeout configuration. Workers consume additional query capacity. Do not equate thousands of simultaneous clients with thousands of simultaneously executing ClickHouse queries.

Record the current PostgreSQL configuration and the size that will remain after purge:

```sql
SELECT name, setting, unit, pending_restart
FROM pg_settings
WHERE name IN ('shared_buffers', 'effective_cache_size', 'work_mem', 'maintenance_work_mem');

SELECT pg_size_pretty(pg_database_size(current_database())) AS database_size,
       pg_size_pretty(pg_total_relation_size('heartbeats')) AS heartbeat_size,
       pg_size_pretty(pg_total_relation_size('dashboard_rollups')) AS rollup_size;
```

The design benchmark selected the current query layouts and found sampled ClickHouse product queries within a 250 ms p95 budget. It used about 1.75 million rows across six account-size cohorts and did not measure full production cardinality or concurrent traffic. Its retained `system.query_log` records show a roughly 74 MiB p99 and 83 MiB maximum for ordinary product query shapes. A representative full export of 1.1 million user rows completed under the proposed profile with 590 MiB tracked memory, while the exact homepage aggregation used 78 MiB. The 1 GiB cap is therefore deliberately finite but still has substantial measured headroom. It remains evidence from a sampled workload, not proof that full production cardinality will meet the memory or no-regression target.

After the full backfill, replay production-shaped reads against the production ClickHouse database at the configured limits before the final fence. Include concurrent dashboards, profiles, homepage totals, leaderboards and exports while merges are active. The current cold signed-in dashboard performs 13 sequential ClickHouse reads, a public profile performs 11 and common stats API calls perform one or two. Exercise that actual fan-out at the expected peak and at twice the expected peak, including a cold-cache burst: application `Rails.cache.fetch` calls do not coalesce concurrent misses. Test ingestion concurrency on an isolated restored copy, not the cutover database: ClickHouse-only test heartbeats would intentionally make production verification fail. A cutover gate passes only when:

- user-facing p95 and p99 show no statistically meaningful regression against the captured PostgreSQL baseline at the same concurrency;
- no query hits a memory or execution-time limit;
- no request is rejected with `TOO_MANY_SIMULTANEOUS_QUERIES` at expected peak and overload sheds cleanly rather than exhausting Rails;
- ClickHouse container working set, host available memory and PostgreSQL latency remain stable during backfill and read load;
- insert parts and merge backlog return to baseline after the test.

Record burst and sustained rates separately. At the benchmark's roughly 20 ms average query latency, 1,000 one-query API calls are a very different workload from 1,000 cold dashboards that fan out to about 13,000 queries. This single-node plan does not assume the latter will meet the latency target. If that is a required production burst, reduce the dashboard query count, add cache-miss coalescing or add independently tested read capacity before cutover.

Use the Coolify container graphs for cgroup working set and inspect finished ClickHouse queries with:

```sql
SYSTEM FLUSH LOGS;

SELECT normalized_query_hash,
       count() AS executions,
       quantileExact(0.95)(query_duration_ms) AS p95_ms,
       quantileExact(0.99)(query_duration_ms) AS p99_ms,
       formatReadableSize(max(memory_usage)) AS max_tracked_memory,
       max(read_rows) AS max_read_rows,
       formatReadableSize(max(read_bytes)) AS max_read_bytes
FROM system.query_log
WHERE type = 'QueryFinish'
  AND event_time >= now() - INTERVAL 1 HOUR
  AND user = 'hackatime_app'
GROUP BY normalized_query_hash
ORDER BY max(memory_usage) DESC
LIMIT 30;
```

Per `agent-query-safety`, self-hosted ClickHouse does not provide safe query memory, spill or execution-time defaults. The enforced settings profile is the guardrail. The 1 GiB value is a per-query kill-switch, not a reservation: measured ordinary reads used roughly 74–83 MiB. Aggregate application-query memory is separately capped at 8 GiB. Each query may use at most four processing threads and the server fairly shares 48 processing slots across at most 32 running queries.

The per-user query count is intentionally higher than the server count. ClickHouse's server-wide `max_concurrent_queries` supports the bounded `queue_max_wait_ms`; its per-user limit does not and immediately rejects excess work. A short burst can therefore wait up to two seconds for one of the 32 server slots, while sustained overload is rejected instead of consuming the node. This is backpressure, not capacity: normal peak traffic must pass the load gate without relying on the queue. If it does not, first reduce dashboard fan-out, add cache-miss coalescing or move heavy batch work to a separate ClickHouse workload. Do not raise concurrency or memory merely to make the test green.

If a production-shaped query reaches 1 GiB, inspect its scan, sort and grouping shape and chunk or optimise it instead of increasing the global application profile. Grant a larger limit only to a separately controlled operator path after measuring that exact operation.

## 2. Establish backup and restore evidence

Configure a Coolify Scheduled Task on the ClickHouse component. Start with a synchronous daily full backup while measuring duration and object-storage cost. This command creates a unique S3 child path and fails the task if the backup fails:

```sh
sh -eu -c '
name="full/$(date -u +%Y%m%dT%H%M%SZ)"
clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" \
  --query "BACKUP DATABASE hackatime TO S3(hackatime_backups, '\''${name}'\'')"
'
```

Run it manually once before relying on its schedule. Then check both Coolify's task result, the object-store path and ClickHouse's record:

```sql
SELECT id, name, status, start_time, end_time, compressed_size, error
FROM system.backups
ORDER BY start_time DESC
LIMIT 10;
```

If daily full backups cannot finish inside the accepted RPO or cost budget, move to a tested weekly-full plus daily-incremental chain using ClickHouse's `base_backup` setting. Do not improvise the chain during an incident. Alert on the absence of a recent `BACKUP_CREATED`, any `BACKUP_FAILED`, object-store write failure and backup age exceeding the accepted RPO.

Before backfill, restore one backup into an isolated ClickHouse `26.7.3.19` instance with the same config and enough disk:

```sql
RESTORE DATABASE hackatime AS hackatime_restore_drill
FROM S3(hackatime_backups, 'full/BACKUP_NAME');
```

Compare table counts, minimum/maximum heartbeat IDs, active parts and sampled dashboard/profile queries. Time the full server rebuild, restore and application recovery. This measured duration is the RTO. A restore on the production node alone is not a disaster-recovery drill.

Before cutover, record in the incident/runbook system:

- backup name, completion timestamp and `BACKUP_CREATED` status;
- canonical `max(id)`, `max(version)`, `max(store_version)` and row count;
- accepted ordinary-heartbeat RPO and measured RTO;
- operator, restore-drill date and result.

Account transfer, account deletion and JA4 nullification controls are durable in PostgreSQL and can be conservatively replayed after restoring a stale ClickHouse backup. Ordinary heartbeats newer than that backup cannot be recreated after PostgreSQL purge. Individual heartbeat deletion/restore also has no PostgreSQL lifecycle control and can be undone by restoring an older backup.

## 3. Online backfill

First finish every recorded transfer, account deletion and JA4 nullification. Then set `HEARTBEAT_MUTATIONS_STOPPED=1` on every web and worker process. This fence blocks individual heartbeat delete/restore, account merge/deletion and JA4 deletion at both admission and job execution, while direct and imported heartbeat ingestion continues in PostgreSQL.

In Coolify, change `HEARTBEAT_MUTATIONS_STOPPED` to `1` on web and worker and redeploy both. Leave `HEARTBEAT_STORE=postgresql` and `HEARTBEAT_WRITES_STOPPED=0`. Verify each running component, not only the saved Coolify configuration:

```sh
bin/rails runner 'puts({
  store: HeartbeatRepository.store,
  writes_stopped: ENV["HEARTBEAT_WRITES_STOPPED"],
  mutations_stopped: ENV["HEARTBEAT_MUTATIONS_STOPPED"]
}.inspect)'
```

Expected output contains `store: "postgresql"`, `writes_stopped: "0"` and `mutations_stopped: "1"`.

The first pass records an upper ID boundary and durable progress in `heartbeat_cutovers`:

```sh
HEARTBEAT_STORE=postgresql HEARTBEAT_MUTATIONS_STOPPED=1 \
  bin/rake clickhouse:backfill
```

The repository groups every payload insert by destination month before applying its 10,000-row cap. This keeps historical backfill, transfer, deletion and repair below ClickHouse's partition-per-insert limit rather than raising the server safety limit. Verification reads PostgreSQL rows in ID order but looks up ClickHouse rows by each layout's full sorting-key tuple, so it does not repeatedly scan a bare global ID range.

Keep the mutation fence enabled through purge. PostgreSQL can continue accepting append-only heartbeats during the first pass because the final pass captures IDs above the first boundary. The task rejects an incomplete lifecycle queue, so do not set the fence until existing controls have completed.

The task is resumable: rerunning it continues from `heartbeat_cutovers.backfilled_through_id`. Do not delete or edit the cutover row. Watch the progress without exposing credentials:

```sh
bin/rails runner 'pp HeartbeatCutover.find(1).attributes.slice(
  "source_through_id", "backfilled_through_id", "verified_through_id", "verified_at", "purged_at"
)'
```

During backfill, monitor ClickHouse disk, active parts, merges, memory and query failures. Do not raise `max_partitions_per_insert_block`; the repository already splits historical writes by destination month and then by 10,000 rows.

When the online pass completes, take another off-node backup and repeat the restore check against production-shaped data. This is the backup that establishes a meaningful pre-cutover RPO. If a near-zero RPO is required, plan and time a final incremental backup during the write fence. That improves RPO but lengthens the heartbeat-ingestion interruption.

## 4. Final write-fenced cutover

Schedule this phase for a low-traffic window. It fences heartbeat writes, but does not require taking the whole site offline.

### Fence and verify the PostgreSQL source

Also set `HEARTBEAT_WRITES_STOPPED=1` on every web and worker process. The application now rejects direct and imported heartbeat writes as well as every mutation. Backfill extends the recorded boundary to the fenced PostgreSQL maximum and resumes from its durable cursor:

In Coolify, keep `HEARTBEAT_STORE=postgresql`, set both fence values to `1` and redeploy every web and worker component. Verify the three values in every running component using the command above before continuing.

```sh
HEARTBEAT_STORE=postgresql HEARTBEAT_WRITES_STOPPED=1 HEARTBEAT_MUTATIONS_STOPPED=1 \
  bin/rake clickhouse:backfill
HEARTBEAT_STORE=postgresql HEARTBEAT_WRITES_STOPPED=1 HEARTBEAT_MUTATIONS_STOPPED=1 \
  bin/rake clickhouse:drain_outbox
HEARTBEAT_STORE=postgresql HEARTBEAT_WRITES_STOPPED=1 HEARTBEAT_MUTATIONS_STOPPED=1 \
  bin/rake clickhouse:verify
```

Save the complete output of all three commands. `clickhouse:verify` compares PostgreSQL with the canonical store, aliases and both query layouts, checks delivery acknowledgements and records the verified source boundary. Do not continue on a mismatch or timeout.

### Switch all processes while fenced

Capture representative PostgreSQL read outputs before switching. Then set `HEARTBEAT_STORE=clickhouse` on every Coolify web and worker resource while leaving both fences at `1` and redeploy all of them. A brief mixed-read deployment is safe because writes and lifecycle mutations are fenced and verification has made both stores agree. It is not safe to reopen either fence until every process is in ClickHouse mode.

Verify every running component reports `store: "clickhouse"` and both fences as `"1"`. Exercise representative read-only paths:

- signed-in dashboard for today and a historical range;
- profile heatmap and project breakdown;
- homepage aggregate;
- leaderboard/streak reads;
- a Sailors Log read if enabled.

Check application errors, ClickHouse query errors and p95 latency. Keep the fence in place if any result disagrees with the PostgreSQL baseline.

### Purge PostgreSQL: irreversible commit point

Optionally complete the planned final incremental backup now if the accepted RPO requires it. Then permanently remove PostgreSQL heartbeat storage:

```sh
HEARTBEAT_STORE=clickhouse HEARTBEAT_WRITES_STOPPED=1 HEARTBEAT_MUTATIONS_STOPPED=1 \
  bin/rake clickhouse:purge_postgres
```

The purge drains delivery and reruns payload, alias and query-layout verification before truncating PostgreSQL heartbeat payloads and dashboard rollups. Its final PostgreSQL transaction locks the cutover row, rechecks that the source boundary has not advanced, records `purged_at`, truncates the heartbeat payload table and derived dashboard rollup table and resets rollup generations atomically. A request that acquired the lock first either makes the boundary check abort the purge or is included in an earlier verified boundary; a request that acquires it after purge is refused. An interruption rolls the entire purge back. It intentionally leaves the now-empty tables represented in Rails schema history; remove them with an explicit Rails migration in a later release after the operational rollback window expires. Do not reopen either fence if canonical rows, aliases, delivery acknowledgements or either query layout disagree. Only after purge succeeds should the release set both fence variables back to `0` and reopen traffic.

Confirm the durable state:

```sh
bin/rails runner 'cutover = HeartbeatCutover.find(1); puts({
  purged_at: cutover.purged_at,
  postgres_heartbeats: Heartbeat.postgresql_unscoped.count,
  postgres_rollups: DashboardRollup.count
}.inspect)'
```

Expected counts are zero and `purged_at` is present. Now set both fence values to `0` on every web and worker resource and redeploy all components. Submit one normal canary heartbeat through the public API, confirm it is acknowledged, then confirm it appears on the user's dashboard. Watch client rejection and delivery-job rates as traffic resumes.

### Reclaim PostgreSQL memory after purge

Purging heartbeat rows does not change PostgreSQL's 64 GiB `shared_buffers`; that memory remains reserved until PostgreSQL is reconfigured and restarted. If PostgreSQL has no failover replica, this is a separate brief whole-site maintenance event. Do not hide it inside the heartbeat-only write fence.

After measuring the remaining relational working set, set 24 GiB as the initial target through the production PostgreSQL configuration mechanism. For a standard PostgreSQL configuration this can be staged with:

```sql
ALTER SYSTEM SET shared_buffers = '24GB';

SELECT name, setting, unit, pending_restart
FROM pg_settings
WHERE name = 'shared_buffers';
```

Take a current PostgreSQL backup, verify recovery readiness and restart PostgreSQL through Coolify during the approved maintenance window. If the database is replicated, use the tested failover procedure instead of restarting the only primary under traffic. After restart, verify `SHOW shared_buffers`, relational cache misses, temporary-file volume and non-heartbeat request p95/p99.

Retain seven representative days of post-change metrics. The RAM objective passes only if the combined PostgreSQL and ClickHouse container working-set p95 and peak are lower than the pre-migration database baseline while the user-facing latency gate remains green. If relational latency regresses, restore the previous PostgreSQL setting at the next approved restart; do not compensate by automatically enlarging ClickHouse.

This is the irreversible commit point. There is no observation window in which ClickHouse accepts new heartbeats and PostgreSQL remains a lossless rollback target: new ClickHouse rows are intentionally not copied back to PostgreSQL. Before purge, rollback means keeping both fences enabled and switching reads back to the still-complete PostgreSQL table. After purge, rollback means restoring ClickHouse. ClickHouse-mode dashboard, profile and homepage reads use exact ClickHouse queries and do not rebuild PostgreSQL rollups. Initial ClickHouse dashboard data is deferred and expensive repeated global/profile/streak reads retain short application-cache boundaries.

The final write fence is the only ingestion interruption. Keep the online backfill phase unfenced for ordinary writes, schedule the final fence for a low-traffic window and rely on normal client retries for rejected heartbeats. In Coolify, apply stricter fence values before switching the store; never temporarily reopen a fence on one application. Verify the environment reported by both web and worker containers before running the final backfill. Reopen both only after purge and smoke checks.

Account deletion applies ClickHouse tombstones synchronously before relational anonymisation can succeed, with the durable job retained for retry. Account merge commits its durable transfer control with the relational merge and the queued idempotent transfer then moves the heartbeats. While that transfer is pending, both source and surviving target accounts reject heartbeat writes so admission cannot race the two-user move. The surviving account may temporarily omit the transferred activity and global source activity can remain visible. After completion, only the retired source remains permanently blocked. This bounded asynchronous merge behavior is not used for account deletion, where privacy requires synchronous tombstones.

ClickHouse requests made while PostgreSQL admission locks are held use deliberately short budgets: ordinary ingest makes one attempt with a two-second per-request network timeout and a ten-second aggregate monotonic deadline for the admission transaction, while lifecycle mutations make at most two attempts with five-second network timeouts. ClickHouse imports are divided into at most 1,000 records per admission transaction, releasing the PostgreSQL connection and user lock between chunks. A partially completed import remains safe to retry because canonical identity and insert tokens are stable, while the delivery job repairs incomplete layouts. These budgets bound PostgreSQL connection pressure during ClickHouse degradation; tune application concurrency and ClickHouse quotas against this failure mode before cutover.

## 5. Rollback before purge

If final verification, the ClickHouse deployment or read checks fail **before** `clickhouse:purge_postgres` succeeds:

1. Keep both fences at `1` on every process.
2. Set `HEARTBEAT_STORE=postgresql` on every web and worker resource.
3. Redeploy all components and verify their actual environment.
4. Confirm PostgreSQL heartbeat counts and baseline reads.
5. For a prompt retry, set only `HEARTBEAT_WRITES_STOPPED=0`. Keep `HEARTBEAT_MUTATIONS_STOPPED=1`, redeploy and leave the ClickHouse candidate intact. Ordinary append-only heartbeats can resume and the next fenced pass extends the source boundary; the existing backfill remains resumable.
6. Fix the cause, repeat the production-shaped load and restore checks and then rerun the online and final-fence steps.

Do not reopen lifecycle mutations and later resume the existing candidate. A transfer, account deletion, JA4 nullification or individual delete/restore can change PostgreSQL rows at or below `backfilled_through_id`, which the ID cursor will not revisit. If business needs require reopening mutations, treat both the ClickHouse candidate and cutover cursor as disposable:

1. Verify every process is back in PostgreSQL mode, then set both fences to `0` and redeploy. Keep the old ClickHouse service and volume untouched for diagnosis; do not run any backfill, verification or purge task against it.
2. Before retrying, set `HEARTBEAT_MUTATIONS_STOPPED=1` everywhere again, redeploy and complete all lifecycle controls.
3. Provision a new empty ClickHouse Coolify resource and volume from section 1, using the same database name but a new private host. Point every PostgreSQL-mode web and worker process at that new `CLICKHOUSE_URL`, redeploy, verify connectivity and run `clickhouse:migrate`. Do not delete or recreate the old database in place.
4. With no cutover task running, reset PostgreSQL progress only after the command below proves the selected ClickHouse target is empty and the old cutover was not purged:

```sh
HEARTBEAT_STORE=postgresql HEARTBEAT_MUTATIONS_STOPPED=1 bin/rails runner '
  abort "Expected PostgreSQL mode" unless HeartbeatRepository.store == "postgresql"
  cutover = HeartbeatCutover.find_by(id: 1)
  abort "PostgreSQL payloads were already purged" if cutover&.purged_at?
  source_max = Heartbeat.postgresql_unscoped.maximum(:id).to_i
  if cutover && source_max < cutover.source_through_id
    abort "PostgreSQL no longer contains the recorded source boundary"
  end
  counts = %w[heartbeat_store heartbeat_aliases heartbeats heartbeats_by_time].to_h do |table|
    row = ClickHouse::Client.current.select("SELECT count() AS count FROM #{table}").sole
    [table, row.fetch("count").to_i]
  end
  abort "Replacement ClickHouse target is not empty: #{counts.inspect}" if counts.values.any?(&:positive?)
  cutover&.destroy!
  puts "Reset disposable pre-cutover progress; start a new online backfill"
'
```

5. Run `clickhouse:backfill` from the beginning. Retire the old ClickHouse resource only after the replacement has passed cutover, backup and restore verification.

Do not run `purge_postgres` merely to make a failed cutover progress. After purge there is no PostgreSQL payload rollback.

## 6. Monitoring and operating the node

Scrape `/metrics` on private port `9363` using the actual ClickHouse internal DNS name discovered in section 1. Do not assume the host is literally `clickhouse` and do not assign it a Coolify domain. At minimum, alert on:

- container unavailable, restart loop or OOM kill;
- disk free space below 25% warning or 15% critical (**field starting thresholds**);
- sustained growth in active parts per partition, background merge backlog or insert throttling;
- query p95/p99 latency, exception rate, memory-limit errors and queries hitting 60 seconds;
- `TOO_MANY_SIMULTANEOUS_QUERIES` errors and requests spending a material portion of latency waiting for admission;
- a non-zero delivery backlog that does not clear after job retries;
- failed GoodJob delivery, audit, transfer, deletion or JA4 nullification jobs;
- backup failure, missing daily success and backup age beyond the accepted RPO.

Useful operator queries:

```sql
SELECT name, path, formatReadableSize(free_space) AS free,
       formatReadableSize(total_space) AS total
FROM system.disks;

SELECT database, table, partition, count() AS active_parts,
       formatReadableSize(sum(bytes_on_disk)) AS bytes
FROM system.parts
WHERE active AND database = 'hackatime'
GROUP BY database, table, partition
ORDER BY active_parts DESC;

SELECT database, table, elapsed, progress, num_parts
FROM system.merges
WHERE database = 'hackatime'
ORDER BY elapsed DESC;

SELECT user, count() AS active_queries, max(elapsed) AS longest_seconds,
       formatReadableSize(sum(memory_usage)) AS tracked_memory
FROM system.processes
GROUP BY user;

SELECT event, value
FROM system.events
WHERE event IN ('ConcurrencyControlQueriesDelayed', 'ConcurrencyControlSlotsDelayed');

SELECT count() AS pending
FROM hackatime.heartbeat_store FINAL
WHERE canonicalized = false OR (
  canonicalized = true AND duplicate_of IS NULL AND
  (heartbeats_version < version OR heartbeats_by_time_version < version)
);
```

The official MergeTree defaults delay inserts at 1,000 active parts and reject at 3,000 per partition. Alert far earlier and investigate insertion rate, merges and disk latency rather than raising those limits. `FINAL` is required for this correctness model but can make global scans expensive, so trend `read_rows`, `read_bytes`, memory and duration in `system.query_log` for application queries.

Coolify restarts do not replace a backup strategy. Before changing the Compose service, confirm the persistent volume name in Deployable Compose, take a backup and never use **Delete resource and volumes** as an update mechanism.

## 7. Repair query layouts

Failed writes enqueue `HeartbeatDeliveryJob` for the affected user, which repairs pending candidates and independently retries both query layouts without scanning unrelated history. One serial global audit runs daily as a backstop. Account transfer keeps permanent source-key tombstones so a delayed stale insert cannot reactivate the old owner. Repair missing query rows entirely from ClickHouse with:

```sh
HEARTBEAT_STORE=clickhouse bin/rake clickhouse:repair_query_layouts
HEARTBEAT_STORE=clickhouse bin/rake clickhouse:drain_outbox
```

`repair_query_layouts` is not a database restore. It treats canonical `heartbeat_store` rows as the source of truth and reinserts their current visible versions into the derived `heartbeats` and `heartbeats_by_time` layouts. It cannot recreate a missing canonical payload or recover data beyond the backup RPO. `drain_outbox` reconciles pending canonical/delivery state before or after the layout rebuild.

The repair task processes one canonical store month and at most 10,000 rows at a time. It is bounded and resumable rather than one global all-history sort. Run a full repair during a low-traffic period because it still reads and writes all canonical history. To resume a stopped repair, use the last progress line:

```sh
HEARTBEAT_STORE=clickhouse TABLE=heartbeats_by_time PARTITION=202608 \
  AFTER_USER_ID=123 AFTER_ID=456 bin/rake clickhouse:repair_query_layouts
```

Use `TABLE=heartbeats` or `TABLE=heartbeats_by_time` and `PARTITION=YYYYMM` to repair only a known affected slice. `AFTER_USER_ID` and `AFTER_ID` are valid only when both `TABLE` and `PARTITION` are set. The task verifies the visible version of each batch before advancing its progress line.

After PostgreSQL purge, do not run `clickhouse:verify`: that command intentionally compares ClickHouse with the pre-purge PostgreSQL payload table. Use repair's checks, `drain_outbox`, the pending query above and representative user/global reads.

## 8. Restore after ClickHouse loss

After restoring a ClickHouse backup, keep web traffic unavailable and set both write fences to `1` on every process. PostgreSQL lifecycle rows must be retained for at least as long as the oldest recoverable ClickHouse backup. Account transfers, account deletions and JA4 nullifications are replayable because they have durable PostgreSQL controls. Individual heartbeat delete/restore actions do not have equivalent PostgreSQL controls; restoring a backup from before one of those actions can undo it. Those actions, like newly ingested heartbeat payloads, are therefore inside the accepted ClickHouse backup RPO. The recovery task first advances the PostgreSQL heartbeat ID and version sequences past every value in the restored canonical store, alias index and retained lifecycle controls. This prevents an older PostgreSQL restore from reusing ClickHouse IDs or versions.

Recovery order on a replacement Coolify service is:

1. Provision the exact pinned image, configuration, secrets and empty persistent volume.
2. Recreate the `hackatime_app_profile` and `hackatime_app` SQL access entities and grants from section 1. `BACKUP DATABASE hackatime` does not include them.
3. Restore `DATABASE hackatime` from the selected off-node backup.
4. Point fenced web and worker resources at the replacement private host, but do not reopen traffic.
5. Run `HEARTBEAT_STORE=clickhouse bin/rake clickhouse:migrate` to apply any release migrations newer than the backup.
6. Run the lifecycle replay task below.
7. Check its completion, the pending query, disk/parts health and representative reads.
8. Record the actual data-loss window and recovery duration.
9. Clear both fences on every process, redeploy, then reopen traffic.

The task then takes a stable snapshot of the lifecycle rows, rejects unfinished controls and conservatively replays every retained transfer, account deletion and JA4 nullification in causal order. Only the recovery process temporarily bypasses its local mutation fence; web and worker processes remain fenced. Finally it repairs both query layouts and verifies deleted users, JA4 removal and delivery acknowledgements:

```sh
HEARTBEAT_STORE=clickhouse HEARTBEAT_WRITES_STOPPED=1 HEARTBEAT_MUTATIONS_STOPPED=1 \
  bin/rake clickhouse:replay_lifecycle_controls
```

Do not set `TABLE`, `PARTITION`, `AFTER_USER_ID` or `AFTER_ID` for recovery. The sequence-only step can be rerun independently with `clickhouse:reseed_postgres_sequences` under both fences. Review the completed verification output before reopening reads or accepting writes.

After PostgreSQL purge, rollback means restoring or rebuilding ClickHouse from its canonical store and backups. There is intentionally no PostgreSQL heartbeat restore path.

## 9. Upgrade ClickHouse

The exact server build is a tested compatibility gate, not permission to ignore security releases. For an upgrade:

1. Restore a current production backup into an isolated candidate server.
2. Change the pinned image and the version guard in `clickhouse:migrate` together on a branch.
3. Run migrations plus the required ClickHouse integration, differential, concurrency and task suites.
4. Run a production-sized read/write/backfill/repair benchmark and compare query/merge metrics.
5. Perform a backup, restore and lifecycle-replay drill on the candidate.
6. Confirm rollback to the previous image from its own backup.
7. Only then schedule the production replacement.

Do not change the Coolify image to `latest` and do not bypass the migration version guard.

## Recommendation basis and references

- **Official:** Coolify Compose files own service networking, health checks and persistent storage. Internal services should not publish ports. See [Coolify Docker Compose](https://coolify.io/docs/knowledge-base/docker/compose) and [Coolify persistent storage](https://coolify.io/docs/knowledge-base/persistent-storage).
- **Official:** the ClickHouse image supports explicit users/passwords, init databases and persistent `/var/lib/clickhouse`; `nofile=262144` is the documented container setting. See [Install ClickHouse using Docker](https://clickhouse.com/docs/get-started/setup/self-managed/docker).
- **Official:** settings profiles, per-user limits and SQL-driven users are supported production controls. See [query-level settings](https://clickhouse.com/docs/operations/settings/query-level), [memory limits](https://clickhouse.com/docs/reference/settings/session-settings/max-memory-usage) and [concurrency limits](https://clickhouse.com/docs/reference/settings/session-settings/max-concurrent).
- **Official:** the server-wide query limit supports bounded waiting, while per-user concurrency limits reject immediately; capacity must be measured from the production query mix. See [high-concurrency sizing for user-facing analytics](https://clickhouse.com/resources/engineering/high-concurrency-sizing-user-analytics).
- **Official:** native S3 backups can be full or incremental, named collections keep credentials out of queries and restore drills are required. See [ClickHouse backup and restore](https://clickhouse.com/docs/concepts/features/backup-restore/overview) and [S3 backup endpoints](https://clickhouse.com/docs/concepts/features/backup-restore/s3-endpoint).
- **Official:** monitor queries, merges, parts, memory, disk and backups through system tables or the Prometheus endpoint. See [ClickHouse monitoring](https://clickhouse.com/docs/guides/oss/deployment-and-scaling/monitoring/monitoring) and [system tables](https://clickhouse.com/docs/operations/system-tables).
- **Derived from this implementation:** the fence order, four-table ownership, month-bounded insertion, verification, purge transaction, repair semantics and lifecycle replay commands.
- **Field starting points:** the 24 CPU/32 GiB container, 24 GiB tracked server, 1 GiB query, 8 GiB Rails user, four threads per query, 32 server query slots with a two-second overflow wait, 256 MiB spill, 24 GiB post-purge PostgreSQL target and disk alert thresholds. These are workload-specific hypotheses, not official defaults. Change them only from measured production behavior while preserving headroom.
