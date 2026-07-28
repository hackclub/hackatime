const endpoint = process.env.CLICKHOUSE_URL ?? "http://localhost:8123"
const database = "hackatime_schema_benchmark"
const rowCount = Number.parseInt(process.env.BENCHMARK_ROWS ?? "2000000", 10)
const iterations = Number.parseInt(process.env.BENCHMARK_ITERATIONS ?? "5", 10)

const plainColumns = `
  id UInt64,
  user_id Int64,
  time Float64,
  project Nullable(String),
  branch Nullable(String),
  entity Nullable(String),
  category Nullable(String),
  editor Nullable(String),
  language Nullable(String),
  machine Nullable(String),
  operating_system Nullable(String),
  type Nullable(String),
  user_agent Nullable(String),
  ip_address Nullable(String),
  dependencies Array(String),
  lineno Nullable(Int32),
  lines Nullable(Int32),
  cursorpos Nullable(Int32),
  line_additions Nullable(Int32),
  line_deletions Nullable(Int32),
  project_root_count Nullable(Int32),
  is_write Nullable(Bool),
  source_type Int32,
  ysws_program Int32,
  ja4_id Nullable(Int32),
  deleted_at Nullable(Float64),
  created_at Float64,
  updated_at Float64,
  version UInt64`

const codecColumns = `
  id UInt64 CODEC(Delta(8), LZ4),
  user_id Int64 CODEC(T64, ZSTD(1)),
  time Float64 CODEC(Gorilla(8), ZSTD(1)),
  project Nullable(String) CODEC(ZSTD(3)),
  branch Nullable(String) CODEC(ZSTD(3)),
  entity Nullable(String) CODEC(ZSTD(3)),
  category LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
  editor LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
  language LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
  machine LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
  operating_system LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
  type LowCardinality(Nullable(String)) CODEC(ZSTD(1)),
  user_agent Nullable(String) CODEC(ZSTD(3)),
  ip_address Nullable(String) CODEC(ZSTD(1)),
  dependencies Array(String) CODEC(ZSTD(3)),
  lineno Nullable(Int32) CODEC(T64, ZSTD(1)),
  lines Nullable(Int32) CODEC(T64, ZSTD(1)),
  cursorpos Nullable(Int32) CODEC(T64, ZSTD(1)),
  line_additions Nullable(Int32) CODEC(T64, ZSTD(1)),
  line_deletions Nullable(Int32) CODEC(T64, ZSTD(1)),
  project_root_count Nullable(Int32) CODEC(T64, ZSTD(1)),
  is_write Nullable(Bool) CODEC(ZSTD(1)),
  source_type Int32 CODEC(T64, ZSTD(1)),
  ysws_program Int32 CODEC(T64, ZSTD(1)),
  ja4_id Nullable(Int32) CODEC(T64, ZSTD(1)),
  deleted_at Nullable(Float64) CODEC(Gorilla(8), ZSTD(1)),
  created_at Float64 CODEC(Gorilla(8), ZSTD(1)),
  updated_at Float64 CODEC(Gorilla(8), ZSTD(1)),
  version UInt64 CODEC(T64, ZSTD(1))`

type Layout = {
  name: string
  columns: string
  order: string
  granularity: number
  projection?: string
}

const layouts: Layout[] = [
  {
    name: "plain_bucket_projection",
    columns: `${plainColumns},
      time_bucket_5m UInt32 MATERIALIZED intDiv(toUInt32(time), 300) * 300`,
    order: "user_id, time_bucket_5m, time, id",
    granularity: 4096,
    projection: "SELECT * ORDER BY (time_bucket_5m, user_id, time, id)"
  },
  {
    name: "codec_bucket",
    columns: `${codecColumns},
      time_bucket_5m UInt32 MATERIALIZED intDiv(toUInt32(time), 300) * 300`,
    order: "user_id, time_bucket_5m, time, id",
    granularity: 4096
  },
  {
    name: "codec_bucket_projection",
    columns: `${codecColumns},
      time_bucket_5m UInt32 MATERIALIZED intDiv(toUInt32(time), 300) * 300`,
    order: "user_id, time_bucket_5m, time, id",
    granularity: 4096,
    projection: "SELECT * ORDER BY (time_bucket_5m, user_id, time, id)"
  },
  {
    name: "codec_time",
    columns: codecColumns,
    order: "user_id, time, id",
    granularity: 8192
  },
  {
    name: "codec_time_projection",
    columns: codecColumns,
    order: "user_id, time, id",
    granularity: 8192,
    projection: "SELECT * ORDER BY (time, user_id, id)"
  },
  {
    name: "codec_time_narrow_projection",
    columns: codecColumns,
    order: "user_id, time, id",
    granularity: 8192,
    projection: `SELECT
      user_id, time, id, version, deleted_at, category, project, language, source_type
      ORDER BY (time, user_id, id)`
  }
]

const insertColumns = [
  "id",
  "user_id",
  "time",
  "project",
  "branch",
  "entity",
  "category",
  "editor",
  "language",
  "machine",
  "operating_system",
  "type",
  "user_agent",
  "ip_address",
  "dependencies",
  "lineno",
  "lines",
  "cursorpos",
  "line_additions",
  "line_deletions",
  "project_root_count",
  "is_write",
  "source_type",
  "ysws_program",
  "ja4_id",
  "deleted_at",
  "created_at",
  "updated_at",
  "version"
]

async function query(sql: string): Promise<string> {
  const response = await fetch(endpoint, {
    method: "POST",
    body: sql
  })
  if (!response.ok) {
    throw new Error(`${response.status}: ${await response.text()}`)
  }
  return response.text()
}

async function prepare(): Promise<void> {
  await query(`DROP DATABASE IF EXISTS ${database} SYNC`)
  await query(`CREATE DATABASE ${database}`)
  for (const layout of layouts) {
    const projection = layout.projection
      ? `, PROJECTION by_time (${layout.projection})`
      : ""
    await query(`
      CREATE TABLE ${database}.${layout.name}
      (
        ${layout.columns}
        ${projection}
      )
      ENGINE = ReplacingMergeTree(version)
      PARTITION BY toYYYYMM(toDateTime(time))
      ORDER BY (${layout.order})
      SETTINGS index_granularity = ${layout.granularity},
        deduplicate_merge_projection_mode = 'rebuild'`)
    await query(`
      INSERT INTO ${database}.${layout.name} (${insertColumns.join(", ")})
      SELECT
        number AS id,
        toInt64(number % 40) + 1 AS user_id,
        1735689600.0 + intDiv(number, 40) * 600 AS time,
        concat('project-', toString(intDiv(number, 40) % 20)) AS project,
        if(intDiv(number, 40) % 2 = 0, 'main', 'feature') AS branch,
        concat('src/file-', toString(intDiv(number, 40) % 1000), '.rs') AS entity,
        if(intDiv(number, 40) % 25 = 0, 'ai coding', 'coding') AS category,
        ['zed', 'vscode', 'neovim'][intDiv(number, 40) % 3 + 1] AS editor,
        ['Rust', 'TypeScript', 'Svelte', 'Ruby'][intDiv(number, 40) % 4 + 1] AS language,
        ['laptop', 'desktop'][intDiv(number, 40) % 2 + 1] AS machine,
        ['Linux', 'Mac', 'Windows'][intDiv(number, 40) % 3 + 1] AS operating_system,
        'file' AS type,
        'wakatime/v1.115.2 (linux-x86_64) go1.23 zed/1.0' AS user_agent,
        '203.0.113.10' AS ip_address,
        ['serde', 'tokio'] AS dependencies,
        toInt32(intDiv(number, 40) % 1000) AS lineno,
        toInt32(1000) AS lines,
        toInt32(intDiv(number, 40) % 100) AS cursorpos,
        toInt32(intDiv(number, 40) % 10) AS line_additions,
        toInt32(0) AS line_deletions,
        toInt32(1) AS project_root_count,
        intDiv(number, 40) % 2 = 0 AS is_write,
        toInt32(0) AS source_type,
        toInt32(0) AS ysws_program,
        CAST(NULL, 'Nullable(Int32)') AS ja4_id,
        if(
          duplicate = 1,
          CAST(1735689600.0 + intDiv(number, 40) * 600 AS Nullable(Float64)),
          CAST(NULL, 'Nullable(Float64)')
        ) AS deleted_at,
        1760000000.0 AS created_at,
        1760000000.0 + duplicate AS updated_at,
        toUInt64(duplicate + 1) AS version
      FROM numbers(${rowCount})
      ARRAY JOIN range(if(number % 100 = 0, 2, 1)) AS duplicate`)
    await query(`OPTIMIZE TABLE ${database}.${layout.name} FINAL`)
  }
}

const end = 1735689600 + Math.floor(rowCount / 40) * 600

function range(layout: Layout, start: number, finish: number): string {
  const exact = `time >= ${start} AND time < ${finish}`
  if (!layout.name.includes("bucket")) {
    return exact
  }

  const firstBucket = Math.floor(start / 300) * 300
  const bucketAfterLast = Math.floor(finish / 300) * 300 + 300
  return `${exact}
    AND time_bucket_5m >= ${firstBucket}
    AND time_bucket_5m < ${bucketAfterLast}`
}

const cases = [
  {
    name: "user total 1 day",
    sql: (layout: Layout) => `
      SELECT sum(diff)
      FROM (
        SELECT least(time - lagInFrame(time, 1, time) OVER (
          ORDER BY time, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 120) AS diff
        FROM ${database}.${layout.name} FINAL
        WHERE user_id = 7 AND deleted_at IS NULL
          AND ${range(layout, end - 86400, end)}
      )`
  },
  {
    name: "user total 30 days",
    sql: (layout: Layout) => `
      SELECT sum(diff)
      FROM (
        SELECT least(time - lagInFrame(time, 1, time) OVER (
          ORDER BY time, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 120) AS diff
        FROM ${database}.${layout.name} FINAL
        WHERE user_id = 7 AND deleted_at IS NULL
          AND ${range(layout, end - 30 * 86400, end)}
      )`
  },
  {
    name: "project totals 30 days",
    sql: (layout: Layout) => `
      SELECT project, sum(diff)
      FROM (
        SELECT project, least(time - lagInFrame(time, 1, time) OVER (
          PARTITION BY project ORDER BY time, id
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 120) AS diff
        FROM ${database}.${layout.name} FINAL
        WHERE user_id = 7 AND deleted_at IS NULL
          AND ${range(layout, end - 30 * 86400, end)}
      )
      GROUP BY project`
  },
  {
    name: "language totals 30 days",
    sql: (layout: Layout) => `
      SELECT language, sum(diff)
      FROM (
        SELECT language, least(time - lagInFrame(time, 1, time) OVER (
          PARTITION BY language ORDER BY time, id
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 120) AS diff
        FROM ${database}.${layout.name} FINAL
        WHERE user_id = 7 AND deleted_at IS NULL
          AND ${range(layout, end - 30 * 86400, end)}
      )
      GROUP BY language`
  },
  {
    name: "project filter 30 days",
    sql: (layout: Layout) => `
      SELECT sum(diff)
      FROM (
        SELECT least(time - lagInFrame(time, 1, time) OVER (
          ORDER BY time, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 120) AS diff
        FROM ${database}.${layout.name} FINAL
        WHERE user_id = 7 AND deleted_at IS NULL AND project = 'project-3'
          AND ${range(layout, end - 30 * 86400, end)}
      )`
  },
  {
    name: "arbitrary range",
    sql: (layout: Layout) => `
      SELECT sum(diff)
      FROM (
        SELECT least(time - lagInFrame(time, 1, time) OVER (
          ORDER BY time, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 120) AS diff
        FROM ${database}.${layout.name} FINAL
        WHERE user_id = 7 AND deleted_at IS NULL
          AND ${range(layout, end - 172837, end - 371)}
      )`
  },
  {
    name: "global total 1 day",
    sql: (layout: Layout) => `
      SELECT sum(diff)
      FROM (
        SELECT least(time - lagInFrame(time, 1, time) OVER (
          PARTITION BY user_id ORDER BY time, id
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 120) AS diff
        FROM ${database}.${layout.name} FINAL
        WHERE deleted_at IS NULL AND ${range(layout, end - 86400, end)}
      )`
  },
  {
    name: "active users 1 day",
    sql: (layout: Layout) => `
      SELECT uniqExact(user_id)
      FROM ${database}.${layout.name} FINAL
      WHERE deleted_at IS NULL AND category = 'coding'
        AND ${range(layout, end - 86400, end)}`
  }
]

async function measure(sql: string): Promise<number[]> {
  await query(sql)
  await query(sql)
  const samples = []
  for (let index = 0; index < iterations; index += 1) {
    const started = performance.now()
    await query(sql)
    samples.push(performance.now() - started)
  }
  return samples.sort((left, right) => left - right)
}

function percentile(samples: number[], ratio: number): number {
  return samples[Math.min(samples.length - 1, Math.floor(samples.length * ratio))] ?? 0
}

await prepare()

const results = []
for (const layout of layouts) {
  for (const benchmarkCase of cases) {
    const samples = await measure(benchmarkCase.sql(layout))
    results.push({
      layout: layout.name,
      case: benchmarkCase.name,
      meanMs: samples.reduce((sum, value) => sum + value, 0) / samples.length,
      p50Ms: percentile(samples, 0.5),
      p95Ms: percentile(samples, 0.95)
    })
  }
}

const storage = JSON.parse(
  await query(`
    SELECT
      table,
      sum(rows) AS rows,
      sum(bytes_on_disk) AS bytesOnDisk,
      sum(data_compressed_bytes) AS compressedBytes,
      sum(data_uncompressed_bytes) AS uncompressedBytes
    FROM system.parts
    WHERE active AND database = '${database}'
    GROUP BY table
    ORDER BY table
    FORMAT JSON`)
).data

const report = {
  generatedAt: new Date().toISOString(),
  clickhouseVersion: (await query("SELECT version()")).trim(),
  inputs: ["current raw schema", "origin/clickhouse raw schema"],
  rowsRequested: rowCount,
  replacementVersionsGenerated: Math.ceil(rowCount / 100),
  rowsAfterFinalMerge: rowCount,
  users: 40,
  iterations,
  layouts,
  storage,
  results
}

await Bun.write(
  new URL("../clickhouse-schema-benchmark.json", import.meta.url),
  `${JSON.stringify(report, null, 2)}\n`
)
process.stdout.write(`${JSON.stringify(report, null, 2)}\n`)
