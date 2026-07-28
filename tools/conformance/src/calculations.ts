type Heartbeat = {
  category: string | null
  language: string | null
  operating_system: string | null
  project: string | null
  time: number
  user_id: number
}

type HeartbeatResponse = {
  heartbeats: Heartbeat[]
}

type Calculation = {
  heartbeatCount: number
  userCount: number
  totalSeconds: number
}

type CalculationReport = {
  passed: boolean
  expected: Record<string, Calculation>
  reference: Record<string, Calculation>
  candidate: Record<string, Calculation>
  mismatches: string[]
}

type Filter = (heartbeat: Heartbeat) => boolean

const fixtureStart = Date.parse("2026-01-10T12:00:00Z") / 1000
const fixtureEnd = Date.parse("2026-01-10T12:47:00Z") / 1000
const expected: Record<string, Calculation> = {
  all: { heartbeatCount: 48, userCount: 1, totalSeconds: 2820 },
  "language:rust": { heartbeatCount: 24, userCount: 1, totalSeconds: 1440 },
  "operating-system:linux": { heartbeatCount: 48, userCount: 1, totalSeconds: 2820 },
  "project:alpha": { heartbeatCount: 24, userCount: 1, totalSeconds: 1380 },
  "start-date": { heartbeatCount: 36, userCount: 1, totalSeconds: 2100 },
  "end-date": { heartbeatCount: 37, userCount: 1, totalSeconds: 2160 },
  "start-and-end-date": { heartbeatCount: 25, userCount: 1, totalSeconds: 1440 },
  "category:ai-coding": { heartbeatCount: 4, userCount: 1, totalSeconds: 180 }
}

function calculate(heartbeats: Heartbeat[], filter: Filter): Calculation {
  const selected = heartbeats.filter(filter).sort((left, right) => left.time - right.time)
  const totalSeconds = selected.slice(1).reduce((total, heartbeat, index) => {
    return total + Math.min(heartbeat.time - selected[index]!.time, 120)
  }, 0)

  return {
    heartbeatCount: selected.length,
    userCount: new Set(selected.map(({ user_id }) => user_id)).size,
    totalSeconds
  }
}

function matrix(heartbeats: Heartbeat[]): Record<string, Calculation> {
  const inFixture = (heartbeat: Heartbeat) =>
    heartbeat.time >= fixtureStart && heartbeat.time <= fixtureEnd
  const filtered = heartbeats.filter(inFixture)

  return {
    all: calculate(filtered, () => true),
    "language:rust": calculate(filtered, ({ language }) => language === "Rust"),
    "operating-system:linux": calculate(
      filtered,
      ({ operating_system }) => operating_system === "linux"
    ),
    "project:alpha": calculate(filtered, ({ project }) => project === "alpha"),
    "start-date": calculate(filtered, ({ time }) => time >= fixtureStart + 12 * 60),
    "end-date": calculate(filtered, ({ time }) => time <= fixtureStart + 36 * 60),
    "start-and-end-date": calculate(
      filtered,
      ({ time }) => time >= fixtureStart + 12 * 60 && time <= fixtureStart + 36 * 60
    ),
    "category:ai-coding": calculate(filtered, ({ category }) => category === "ai coding")
  }
}

async function fetchHeartbeats(baseUrl: string, apiKey: string): Promise<Heartbeat[]> {
  const start = encodeURIComponent(new Date(fixtureStart * 1000).toISOString())
  const end = encodeURIComponent(new Date(fixtureEnd * 1000).toISOString())
  const response = await fetch(
    new URL(`/api/v1/my/heartbeats?start_time=${start}&end_time=${end}`, baseUrl),
    { headers: { authorization: `Bearer ${apiKey}` } }
  )

  if (!response.ok) {
    throw new Error(`heartbeat fetch returned ${response.status}: ${await response.text()}`)
  }

  return ((await response.json()) as HeartbeatResponse).heartbeats
}

export async function verifyCalculations(
  referenceUrl: string,
  candidateUrl: string,
  apiKey: string
): Promise<CalculationReport> {
  const [referenceHeartbeats, candidateHeartbeats] = await Promise.all([
    fetchHeartbeats(referenceUrl, apiKey),
    fetchHeartbeats(candidateUrl, apiKey)
  ])
  const reference = matrix(referenceHeartbeats)
  const candidate = matrix(candidateHeartbeats)
  const mismatches = Object.keys(expected).flatMap((name) => {
    const expectedValue = JSON.stringify(expected[name])
    return JSON.stringify(reference[name]) === expectedValue &&
      JSON.stringify(candidate[name]) === expectedValue
      ? []
      : [name]
  })

  return {
    passed: mismatches.length === 0,
    expected,
    reference,
    candidate,
    mismatches
  }
}
