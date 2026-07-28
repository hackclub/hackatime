const source =
  process.env.OPENAPI_URL ?? "http://localhost:3002/api-docs/openapi.json";
const response = await fetch(source);

if (!response.ok) {
  throw new Error(`openapi download failed with ${response.status}`);
}

const document = await response.text();
await Bun.write("openapi.json", document);

const processResult = Bun.spawnSync({
  cmd: [
    "bunx",
    "openapi-typescript",
    "openapi.json",
    "--output",
    "src/lib/api/schema.d.ts",
  ],
  stdout: "inherit",
  stderr: "inherit",
});

if (processResult.exitCode !== 0) {
  process.exit(processResult.exitCode);
}
