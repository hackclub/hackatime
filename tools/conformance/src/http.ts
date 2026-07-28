import { normalize } from "./normalize"
import type { Scenario, Snapshot } from "./types"

const stableHeaders = ["content-type", "location", "retry-after"]

export async function runScenario(
  baseUrl: string,
  scenario: Scenario,
  apiKey: string
): Promise<Snapshot> {
  const headers = new Headers(scenario.headers)
  headers.set("accept", "application/json")

  if (scenario.authenticated) {
    headers.set("authorization", `Bearer ${apiKey}`)
  }

  let body: string | undefined
  if (scenario.body !== undefined) {
    headers.set("content-type", "application/json")
    body = JSON.stringify(scenario.body)
  }

  const response = await fetch(new URL(scenario.path, baseUrl), {
    method: scenario.method,
    headers,
    body,
    redirect: "manual"
  })
  const text = await response.text()
  let responseBody: unknown = text

  if (text.length > 0 && response.headers.get("content-type")?.includes("json")) {
    responseBody = JSON.parse(text)
  }

  const expectedStatuses =
    typeof scenario.expectedStatus === "number"
      ? [scenario.expectedStatus]
      : scenario.expectedStatus
  if (expectedStatuses !== undefined && !expectedStatuses.includes(response.status)) {
    throw new Error(
      `${scenario.name} returned ${response.status}, expected ${expectedStatuses.join(" or ")}: ${text}`
    )
  }

  return {
    name: scenario.name,
    method: scenario.method,
    path: scenario.path,
    status: response.status,
    headers: Object.fromEntries(
      stableHeaders.flatMap((name) => {
        if (name === "content-type" && response.status >= 300 && response.status < 400) {
          return []
        }
        const value = response.headers.get(name)
        if (value === null) {
          return []
        }
        return [[name, name === "content-type" ? value.split(";", 1)[0]! : value]]
      })
    ),
    body: normalize(responseBody, scenario.volatilePaths)
  }
}

export async function capture(
  baseUrl: string,
  scenarios: Scenario[],
  apiKey: string
): Promise<Snapshot[]> {
  const snapshots: Snapshot[] = []
  for (const scenario of scenarios) {
    snapshots.push(await runScenario(baseUrl, scenario, apiKey))
  }
  return snapshots
}
