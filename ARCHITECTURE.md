# Rust and SvelteKit architecture

## Repository layout

The active applications live in `apps/api` and `apps/web`. The previous implementation is isolated in `legacy/rails`. Database initialization lives in `infra` and cross-implementation verification lives in `tools`.

## Runtime

The application is split into four services:

- Axum handles authentication, heartbeat ingestion, public API responses and OpenAPI generation
- SvelteKit renders the browser application and calls the generated API client
- PostgreSQL 18.4 stores the existing relational schema
- ClickHouse 26.7.1 stores heartbeats and executes heartbeat analytics

The legacy Rails service and PostgreSQL 16 service remain in Compose as the reference implementation for conformance checks and benchmarks. The services are named `api`, `web`, `postgres`, `clickhouse`, `legacy-rails` and `legacy-postgres`.

## Backend modules

The Rust backend has seven focused modules:

- `api` owns HTTP extraction and response compatibility
- `config` validates environment configuration
- `date` owns timestamp parsing and timezone boundaries
- `error` maps domain and datastore failures to HTTP responses
- `heartbeat` owns ClickHouse writes and analytics
- `models` owns request, response and relational types
- `users` owns API key authentication and user lookup

There is no repository trait layer, service container or generic domain abstraction. SQL is kept beside the behavior it implements. The design uses crates for transport, serialization, OpenAPI, database access, timezone handling, compression, tracing and error mapping.

## Typed frontend client

Utoipa publishes the live contract at `/api-docs/openapi.json`. `apps/web/scripts/generate-api.ts` stores that contract and generates `schema.d.ts` with `openapi-typescript`. `openapi-fetch` uses the generated path and component types in SvelteKit.

The generated contract contains the 27 documented Rails API paths plus `/up`. Swagger UI is served from `/api-docs`.

## PostgreSQL schema

`infra/migrations/postgres/0001_schema.sql` is generated from the committed Rails schema through a clean PostgreSQL database. It keeps the Rails tables, columns, indexes, sequences and foreign keys. The Rails `heartbeats` table is excluded because the new runtime stores heartbeats only in ClickHouse.

The Compose-only development seed is separate at `infra/docker/postgres/development_seed.sql`. Production schema consumers do not receive development credentials.

## ClickHouse heartbeat layout

The ClickHouse table preserves the logical Rails heartbeat fields except `fields_hash`. That field is an internal PostgreSQL deduplication artifact, is never returned by the API and consumed 92.7 percent of compressed bytes in the synthetic ClickHouse dataset. The deterministic `id` provides ingestion identity without storing the full hash. The table adds one physical field:

- `version` supports idempotent replacement

The primary order is:

```text
user_id, time, id
```

The layout combines the codecs and low-cardinality dimensions from the `clickhouse` branch with a smaller sorting key. A two million row benchmark compared bucketed and full-resolution keys with full, narrow and absent projections. The full-resolution codec layout was the smallest non-projected table and had the lowest aggregate query latency.

A materialized five minute bucket does not reduce cardinality in a useful way when it is followed by the exact timestamp. Ordering by `(bucket, time)` is equivalent to ordering by `time` because the bucket is a monotonic function of time. It adds a stored column and duplicate predicates without improving the measured pruning. ClickHouse uses a sparse primary index rather than one index entry for every distinct timestamp.

The exact timestamp remains authoritative. Duration uses the difference between adjacent heartbeats with a 120 second cap. A pre-aggregated five minute or hourly materialized view is not used for exact duration because adjacency can cross bucket boundaries. Independent bucket totals would lose that boundary information or double count it. A future rollup can serve approximate dashboards but must not replace the exact query path.

`ReplacingMergeTree(version)` plus deterministic IDs makes repeated fixture and client submissions idempotent. Every logical read uses `FINAL` so correctness does not depend on background merge timing.

Replacement identity is the sorting key rather than `id` alone. A deletion appends a newer row with the same key and a populated `deleted_at`. An account move changes `user_id`, so it must append a tombstone under the old user key and a live copy under the new user key. `FINAL` resolves both keys but cannot infer the old-key tombstone by itself.

No serving table, rollup or projection is part of the selected schema.

## Time correctness

Numeric seconds, milliseconds, microseconds, nanoseconds, RFC 3339 strings and date strings are normalized in one place. Local day bounds are constructed in the user timezone before conversion to UTC. Tests cover a normal noninteger offset, invalid timezone fallback, the 23 hour spring DST day and the 25 hour autumn DST day.

Statistics use an inclusive start and exclusive end. Raw heartbeat export keeps Rails-compatible inclusive bounds. This distinction is covered by the conformance harness.

## Migration boundary

The new runtime covers all documented API paths and the simplified SvelteKit dashboard, setup and public profile surfaces. Rails-only administrative screens, background integrations, email flows and browser OAuth management remain in the reference application. They are not silently emulated because their contracts depend on external services and privileged workflows.

There is no PostgreSQL to ClickHouse heartbeat migration and no dual write path, as requested.
