# Development

The repository contains two applications and one reference implementation:

```text
apps/api       Rust API
apps/web       SvelteKit web application
legacy/rails   legacy Rails reference
infra          database initialization
tools          conformance and benchmark tooling
```

Docker Compose is the root development entry point:

```sh
docker compose up -d
```

The SvelteKit application runs at <http://localhost:5173>. The Rust API runs at <http://localhost:3002>. The Rails reference runs at <http://localhost:3000>.

## Rust API

Run Rust checks from `apps/api`:

```sh
cd apps/api
cargo fmt --check
cargo test
cargo clippy --all-targets --all-features -- -D warnings
```

## SvelteKit web

Run web checks from `apps/web`:

```sh
cd apps/web
bun install
bun run generate:api
bun run check
bun run build
```

## Rails reference

Rails remains available only as the reference implementation and migration source. Its container working directory is `/workspace/legacy/rails`, so its internal commands remain conventional:

```sh
docker compose exec legacy-rails bin/rails test
docker compose exec legacy-rails bundle exec rubocop
docker compose exec legacy-rails bin/rails zeitwerk:check
```

The complete legacy guide is at [legacy/rails/DEVELOPMENT.md](legacy/rails/DEVELOPMENT.md).

## Conformance

```sh
bun run tools/conformance/src/cli.ts compare \
  --reference http://localhost:3000 \
  --candidate http://localhost:3002
```
