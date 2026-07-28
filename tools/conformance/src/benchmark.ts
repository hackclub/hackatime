import { runScenario } from "./http"
import type { BenchmarkResult, Scenario } from "./types"

function percentile(sorted: number[], ratio: number): number {
  const index = Math.min(sorted.length - 1, Math.floor(sorted.length * ratio))
  return sorted[index] ?? 0
}

export async function benchmark(
  baseUrl: string,
  scenario: Scenario,
  apiKey: string,
  requests: number,
  concurrency: number
): Promise<BenchmarkResult> {
  const latencies: number[] = []
  const statuses: Record<string, number> = {}
  let next = 0
  const started = performance.now()

  await Promise.all(
    Array.from({ length: concurrency }, async () => {
      while (next < requests) {
        next += 1
        const requestStarted = performance.now()
        const snapshot = await runScenario(baseUrl, scenario, apiKey)
        latencies.push(performance.now() - requestStarted)
        statuses[snapshot.status] = (statuses[snapshot.status] ?? 0) + 1
      }
    })
  )

  const elapsedMs = performance.now() - started
  latencies.sort((left, right) => left - right)
  const total = latencies.reduce((sum, value) => sum + value, 0)

  return {
    name: scenario.name,
    requests,
    concurrency,
    elapsedMs,
    requestsPerSecond: requests / (elapsedMs / 1000),
    latencyMs: {
      min: latencies[0] ?? 0,
      mean: total / latencies.length,
      p50: percentile(latencies, 0.5),
      p95: percentile(latencies, 0.95),
      p99: percentile(latencies, 0.99),
      max: latencies.at(-1) ?? 0
    },
    statuses
  }
}
