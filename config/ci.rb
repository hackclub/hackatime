CI.run do
  step "Setup: Rails", "bin/setup --skip-server"
  step "Style: Ruby", "bin/rubocop"

  step "Zeitwerk", "bin/rails zeitwerk:check"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Setup: Test DB", "env RAILS_ENV=test bin/rails db:create db:schema:load"
  step "Setup: js_from_routes", "bin/rake js_from_routes:generate"
  step "Setup: Vite assets", "env RAILS_ENV=test bin/vite build && env RAILS_ENV=test VITE_CACHE_DIR=node_modules/.vite-test-ssr bin/vite build --ssr"
  step "Tests: Rails", "env RAILS_ENV=test bin/rails test"
  step "Tests: System", "bin/test-system"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  step "Docs: Swagger", "env RAILS_ENV=test bin/rails rswag:specs:swaggerize && git diff --exit-code swagger/"
  step "Docs: Blume", "bun run build:docs"

  step "Frontend: Typecheck", "bun run check:svelte"
  step "Frontend: Format", "bun run format:svelte:check"
  step "Frontend: Lint", "bun run lint"
  step "Frontend: Knip", "bun run knip"

  step "Desktop site: Typecheck", "cd desktop/site && bun install --frozen-lockfile && bun run check"
  # SvelteKit needs Node 22.17+, newer than the web container has, so build with Bun's runtime.
  step "Desktop site: Build", "cd desktop/site && env OAUTH_CLIENT_ID=ci SESSION_SECRET=ci-only-session-secret-not-for-deploys bun --bun run build"
  # The Mac app builds only on macOS (with Xcode 27); GitHub Actions runs it there.
  step "Desktop app: Swift tests", "cd desktop/macos && swift test" if RUBY_PLATFORM.include?("darwin")

  if success?
    heading "Signoff: All systems go. Ready for merge and deploy.", type: :success
  else
    failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  end
end
