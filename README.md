<div align="center">

<img width="456" alt="Hackatime" src="https://github.com/user-attachments/assets/b3036ced-a7ea-4d03-8feb-816a83572e3a#gh-light-mode-only" />
<img width="456" alt="Hackatime" src="https://github.com/user-attachments/assets/1d237c55-d349-44d3-93e6-d9dbb627e4dc#gh-dark-mode-only" />

[![Ping](https://uptime.hackclub.com/api/badge/4/ping)](https://uptime.hackclub.com/status/hackatime)
[![Status](https://uptime.hackclub.com/api/badge/4/status)](https://uptime.hackclub.com/status/hackatime)
[![Work time](https://hackatime-badge.hackclub.com/U0C7B14Q3/harbor)](https://hackatime-badge.hackclub.com)
![Skylight performance data](https://badges.skylight.io/rpm/gekOqYRbWn4F.svg?token=wAp7SSndwPO6w-7TFJvz7G-IXFMCDFmuCjm6wdKzibI&cache-control=no-cache)

[**Documentation**](https://hackatime.hackclub.com/docs)

</div>

<p align="center">The free, open source, WakaTime-compatible coding time tracker from Hack Club.</p>

## Repository layout

```text
apps/api       Rust API
apps/web       SvelteKit web application
legacy/rails   legacy Rails reference
infra          PostgreSQL and ClickHouse initialization
tools          conformance and benchmark tooling
```

Docker Compose at the repository root is the single entry point for the complete stack.

## Rust and SvelteKit development

The rewritten runtime uses Rust, SvelteKit, PostgreSQL and ClickHouse:

```sh
docker compose up -d postgres clickhouse api web
```

The SvelteKit application is available at `http://localhost:5173`. The Rust API is available at `http://localhost:3002` and Swagger UI is available at `http://localhost:3002/api-docs`.

The development user is `testuser` and its API key is `dev-api-key-12345`.

Generate the typed frontend client while the API is running:

```sh
cd apps/web
bun run generate:api
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for storage and correctness decisions. See [BENCHMARKS.md](BENCHMARKS.md) for conformance, throughput and resource results.

## Rails reference

The Rails service remains available for conformance and migration work:

```sh
docker compose up -d legacy-postgres legacy-rails
```

Read [DEVELOPMENT.md](DEVELOPMENT.md) for the legacy workflow.

## Installer repo

Looking for the installer code? It's over at [hackclub/hackatime-setup](https://github.com/hackclub/hackatime-setup).
