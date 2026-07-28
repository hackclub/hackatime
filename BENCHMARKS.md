# Conformance and benchmark report

## Correctness

The Bun and TypeScript harness was built against Rails before the Rust handlers. It now exercises 35 HTTP scenarios against both implementations.

The strict response comparison passes with zero mismatches. It covers authentication, single and bulk ingest errors, user identity, API keys, raw heartbeats, spans, totals, one-sided bounds, combined bounds, project and category filters, AI exclusion, summaries, project reports, trust masking, lookups, badge redirects, live activity and leaderboards.

The independent calculation report validates both implementations against fixed expected values:

| Dimension | Heartbeats | Users | Seconds |
| --- | ---: | ---: | ---: |
| All | 48 | 1 | 2820 |
| Rust language | 24 | 1 | 1440 |
| Linux OS | 48 | 1 | 2820 |
| Alpha project | 24 | 1 | 1380 |
| Start only | 36 | 1 | 2100 |
| End only | 37 | 1 | 2160 |
| Start and end | 25 | 1 | 1440 |
| AI coding | 4 | 1 | 180 |

The report is stored in `tools/conformance/calculation-report.json`.

## Throughput and latency

Each scenario used 1,000 requests at concurrency 20 against the same 48-heartbeat fixture. Rust was compiled with the release profile. Rails ran through the existing development Puma service, so these numbers are useful for local comparison but are not a production capacity claim.

| Scenario | Rails RPS | Rust RPS | Speedup | Rails p95 ms | Rust p95 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Heartbeat spans | 59.23 | 236.21 | 3.99x | 356.91 | 137.99 |
| Total seconds | 91.46 | 207.30 | 2.27x | 270.90 | 147.15 |
| Total by project | 89.20 | 157.28 | 1.76x | 269.79 | 204.51 |
| Summary | 111.97 | 1710.04 | 15.27x | 211.86 | 11.45 |
| Project details | 70.50 | 143.60 | 2.04x | 335.62 | 210.18 |

The original summary result compared different behavior. Rails wraps `/api/summary` in a one-minute `Rails.cache.fetch` and the benchmark repeats one URL 1,000 times. Rust ran two exact grouped ClickHouse windows for every request. The old 0.97x result therefore compares a warmed Rails memory cache with uncached ClickHouse reads.

The Rust endpoint now uses the same one-minute cache lifetime. It reaches 1,710.04 RPS with an 11.45 ms p95 in the repeated-URL test. Raw ClickHouse performance is measured separately so cached HTTP throughput is not presented as database throughput.

Raw results are stored in `tools/conformance/rails.benchmark.json` and `tools/conformance/rust.benchmark.json`.

## ClickHouse raw schema

The schema harness generated two million logical heartbeats across 40 users. It included 20,000 newer deletion versions then compacted each layout before measurement. Every query used `FINAL`. The eight cases cover one-day and 30-day user totals, project and language groups, a project filter, an arbitrary range, a global total and active users.

| Layout | Disk | Aggregate p50 | Geometric p50 |
| --- | ---: | ---: | ---: |
| Plain bucket with full projection | 35.13 MiB | 87.70 ms | 10.76 ms |
| Codec bucket | 4.92 MiB | 96.00 ms | 11.71 ms |
| Codec bucket with full projection | 17.63 MiB | 96.85 ms | 11.96 ms |
| Codec time | 2.75 MiB | 87.29 ms | 10.84 ms |
| Codec time with full projection | 15.09 MiB | 89.57 ms | 11.07 ms |
| Codec time with narrow projection | 11.61 MiB | 88.66 ms | 10.96 ms |

`codec_time`, ordered by `(user_id, time, id)`, is selected. It used 44.2 percent less disk than `codec_bucket` and reduced aggregate p50 latency by 9.1 percent. The full time-first projection used 5.5 times the selected table’s disk. The narrow projection used 4.2 times the disk and was slower across the complete workload.

The bucket result also explains why second-level timestamp cardinality did not hurt this design. ClickHouse’s sparse primary index stores marks by granule. It does not build a conventional per-value B-tree. Since the exact timestamp remains after the bucket, the bucket does not change row order.

Machine-readable results are stored in `tools/conformance/clickhouse-schema-benchmark.json`.

The correction conformance check inserts a normal replacement, a soft deletion and an account move into a temporary copy of the production table. It verifies that `FINAL` exposes only the live row under the destination user. The move deliberately writes both the old-key tombstone and the new-key live row.

## CPU and memory

CPU was measured from cgroup v2 usage deltas across the complete 5,000-request suite. A value of 100 percent is one fully used core.

| Component | CPU seconds | Average CPU | Memory sample |
| --- | ---: | ---: | ---: |
| Rails application | 45.370 | 86.17% | 325.73 MiB |
| Rails PostgreSQL | 10.930 | 20.76% | 47.76 MiB |
| Rust application | 4.427 | 20.14% | 17.73 MiB |
| Rust ClickHouse | 67.440 | 306.81% | 1250.59 MiB |
| Rust PostgreSQL | 2.774 | 12.62% | 59.67 MiB |

Rails completed the resource-measured suite in 52.653 seconds. Rust completed it in 21.981 seconds.

The Rust application process is much smaller and uses far less CPU than Puma. The complete Rust data stack uses 74.642 CPU seconds versus 56.300 for Rails and uses more sampled memory because ClickHouse uses several cores and maintains large caches. The new stack is faster but it is not cheaper for this tiny dataset.

Rails used PostgreSQL 16 and the new Compose runtime used PostgreSQL 18.4. Both databases contained the same conformance identity. ClickHouse behavior will become more favorable as heartbeat volume and analytical scan size grow. Production sizing still requires a representative dataset, release Rails, warmed caches and a longer steady-state test.

Machine-readable resource data is stored in `tools/conformance/resource-usage.json`.

## Commands

```sh
bun run tools/conformance/src/cli.ts compare \
  --reference http://localhost:3000 \
  --candidate http://localhost:3002

bun run tools/conformance/src/cli.ts verify \
  --reference http://localhost:3000 \
  --candidate http://localhost:3002

bun run tools/conformance/src/cli.ts benchmark \
  --base http://localhost:3002 \
  --requests 1000 \
  --concurrency 20

bun run --cwd tools/conformance benchmark:clickhouse

bun run --cwd tools/conformance verify:clickhouse-corrections
```
