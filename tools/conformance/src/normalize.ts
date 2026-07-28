const volatileKeys = new Set([
  "request_id",
  "created_at",
  "updated_at",
  "generated_at",
  "fields_hash"
])

function canonicalize(value: unknown): unknown {
  if (Array.isArray(value)) {
    const normalized = value.map(canonicalize)
    if (normalized.every((child) => child === null || ["boolean", "number", "string"].includes(typeof child))) {
      return normalized.sort((left, right) => JSON.stringify(left).localeCompare(JSON.stringify(right)))
    }
    return normalized
  }

  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .filter(([key]) => !volatileKeys.has(key))
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, child]) => [key, canonicalize(child)])
    )
  }

  if (typeof value === "number" && !Number.isInteger(value)) {
    return Math.round(value * 1_000_000) / 1_000_000
  }

  return value
}

function removePath(value: unknown, segments: string[]): void {
  if (!value || typeof value !== "object" || segments.length === 0) {
    return
  }

  const [head, ...tail] = segments
  if (head === undefined) {
    return
  }

  if (head === "*" && Array.isArray(value)) {
    value.forEach((child) => removePath(child, tail))
    return
  }

  const record = value as Record<string, unknown>
  if (tail.length === 0) {
    delete record[head]
    return
  }

  removePath(record[head], tail)
}

export function normalize(value: unknown, paths: string[] = []): unknown {
  const cloned = structuredClone(value)
  paths.forEach((path) => removePath(cloned, path.split(".")))
  return canonicalize(cloned)
}
