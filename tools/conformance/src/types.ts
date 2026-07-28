export type HttpMethod = "GET" | "POST" | "PATCH" | "DELETE"

export type Scenario = {
  name: string
  method: HttpMethod
  path: string
  authenticated?: boolean
  body?: unknown
  contractOnly?: boolean
  headers?: Record<string, string>
  expectedStatus?: number | number[]
  volatilePaths?: string[]
}

export type Snapshot = {
  name: string
  method: HttpMethod
  path: string
  status: number
  headers: Record<string, string>
  body: unknown
}

export type BenchmarkResult = {
  name: string
  requests: number
  concurrency: number
  elapsedMs: number
  requestsPerSecond: number
  latencyMs: {
    min: number
    mean: number
    p50: number
    p95: number
    p99: number
    max: number
  }
  statuses: Record<string, number>
}
