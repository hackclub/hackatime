const endpoint = process.env.CLICKHOUSE_URL ?? "http://localhost:8123"
const database = "hackatime_correction_conformance"

export {}

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

await query(`DROP DATABASE IF EXISTS ${database} SYNC`)

try {
  await query(`CREATE DATABASE ${database}`)
  await query(
    `CREATE TABLE ${database}.heartbeats AS hackatime.heartbeats`
  )
  await query(`
    INSERT INTO ${database}.heartbeats
      (id, user_id, time, source_type, deleted_at, created_at, updated_at, version)
    VALUES
      (1, 10, 1760000000, 0, NULL, 1760000000, 1760000000, 1),
      (1, 10, 1760000000, 0, 1760000100, 1760000000, 1760000100, 2),
      (2, 20, 1760000200, 0, NULL, 1760000200, 1760000200, 1),
      (2, 20, 1760000200, 0, 1760000300, 1760000200, 1760000300, 2),
      (2, 21, 1760000200, 0, NULL, 1760000200, 1760000300, 2)`)

  const activeRows = JSON.parse(
    await query(`
      SELECT id, user_id
      FROM ${database}.heartbeats FINAL
      WHERE deleted_at IS NULL
      ORDER BY id, user_id
      FORMAT JSON`)
  ).data

  const expected = [{ id: 2, user_id: 21 }]
  if (JSON.stringify(activeRows) !== JSON.stringify(expected)) {
    throw new Error(
      `unexpected FINAL correction result: ${JSON.stringify(activeRows)}`
    )
  }

  process.stdout.write(
    `${JSON.stringify({ status: "ok", activeRows }, null, 2)}\n`
  )
} finally {
  await query(`DROP DATABASE IF EXISTS ${database} SYNC`)
}
