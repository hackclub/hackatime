const timestamp = Date.parse("2026-01-10T12:00:00Z") / 1000

const dimensions = [
  { project: "alpha", language: "Rust", operating_system: "Linux", editor: "Zed" },
  { project: "alpha", language: "Svelte", operating_system: "Linux", editor: "Zed" },
  { project: "beta", language: "TypeScript", operating_system: "Mac", editor: "VS Code" },
  { project: "beta", language: "Rust", operating_system: "Windows", editor: "Neovim" }
]

export const fixtureHeartbeats = Array.from({ length: 48 }, (_, index) => {
  const dimension = dimensions[Math.floor(index / 12) % dimensions.length]!
  return {
    entity: `src/conformance-${index}.${dimension.language === "Rust" ? "rs" : "ts"}`,
    type: "file",
    time: timestamp + index * 60,
    category: index >= 36 && index < 40 ? "ai coding" : "coding",
    branch: index % 2 === 0 ? "main" : "feature",
    machine: index % 3 === 0 ? "desktop" : "laptop",
    is_write: index % 2 === 0,
    ...dimension
  }
})

export async function seed(baseUrl: string, apiKey: string): Promise<void> {
  for (let offset = 0; offset < fixtureHeartbeats.length; offset += 100) {
    const response = await fetch(
      new URL("/api/hackatime/v1/users/current/heartbeats.bulk", baseUrl),
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${apiKey}`,
          "cf-connecting-ip": "203.0.113.10",
          "content-type": "application/json",
          "user-agent": "wakatime/v1.115.2 (linux-x86_64) go1.23 zed/1.0"
        },
        body: JSON.stringify(fixtureHeartbeats.slice(offset, offset + 100))
      }
    )

    if (!response.ok) {
      throw new Error(`seed failed with ${response.status}: ${await response.text()}`)
    }
  }
}
