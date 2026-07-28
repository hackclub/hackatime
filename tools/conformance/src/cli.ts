import { parseArgs } from "node:util"
import { benchmark } from "./benchmark"
import { verifyCalculations } from "./calculations"
import { capture } from "./http"
import { benchmarkScenarios, scenarios } from "./scenarios"
import { seed } from "./seed"

const { positionals, values } = parseArgs({
  args: Bun.argv.slice(2),
  allowPositionals: true,
  options: {
    base: { type: "string" },
    reference: { type: "string" },
    candidate: { type: "string" },
    out: { type: "string" },
    apiKey: { type: "string", default: "dev-api-key-12345" },
    requests: { type: "string", default: "500" },
    concurrency: { type: "string", default: "20" },
    scenario: { type: "string" }
  }
})

const command = positionals[0]
const apiKey = values.apiKey!

if (command === "seed") {
  await seed(values.base ?? "http://localhost:3000", apiKey)
} else if (command === "capture") {
  const snapshots = await capture(values.base ?? "http://localhost:3000", scenarios, apiKey)
  const output = `${JSON.stringify(snapshots, null, 2)}\n`
  if (values.out) {
    await Bun.write(values.out, output)
  } else {
    process.stdout.write(output)
  }
} else if (command === "compare") {
  if (!values.reference || !values.candidate) {
    throw new Error("compare requires --reference and --candidate")
  }
  const [reference, candidate] = await Promise.all([
    capture(values.reference, scenarios, apiKey),
    capture(values.candidate, scenarios, apiKey)
  ])
  const mismatches = reference.flatMap((snapshot, index) => {
    const candidateSnapshot = candidate[index]
    return scenarios[index]?.contractOnly ||
      JSON.stringify(snapshot) === JSON.stringify(candidateSnapshot)
      ? []
      : [{ name: snapshot.name, reference: snapshot, candidate: candidateSnapshot }]
  })
  process.stdout.write(`${JSON.stringify({ passed: mismatches.length === 0, mismatches }, null, 2)}\n`)
  if (mismatches.length > 0) {
    process.exitCode = 1
  }
} else if (command === "benchmark") {
  const baseUrl = values.base ?? "http://localhost:3000"
  const requests = Number.parseInt(values.requests!, 10)
  const concurrency = Number.parseInt(values.concurrency!, 10)
  const selectedScenarios = values.scenario
    ? benchmarkScenarios.filter(({ name }) => name === values.scenario)
    : benchmarkScenarios
  if (selectedScenarios.length === 0) {
    throw new Error(`unknown benchmark scenario: ${values.scenario}`)
  }
  const results = []
  for (const scenario of selectedScenarios) {
    results.push(await benchmark(baseUrl, scenario, apiKey, requests, concurrency))
  }
  const output = `${JSON.stringify(results, null, 2)}\n`
  if (values.out) {
    await Bun.write(values.out, output)
  } else {
    process.stdout.write(output)
  }
} else if (command === "verify") {
  if (!values.reference || !values.candidate) {
    throw new Error("verify requires --reference and --candidate")
  }
  const report = await verifyCalculations(values.reference, values.candidate, apiKey)
  const output = `${JSON.stringify(report, null, 2)}\n`
  if (values.out) {
    await Bun.write(values.out, output)
  } else {
    process.stdout.write(output)
  }
  if (!report.passed) {
    process.exitCode = 1
  }
} else {
  throw new Error("expected seed, capture, compare, verify or benchmark")
}
