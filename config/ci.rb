CI.run do
  step "Setup: Rails", "bin/setup --skip-server"
  step "Setup: Frontend", "bun install --frozen-lockfile"
  step "Style: Ruby", "bin/rubocop"

  step "Zeitwerk", "bin/rails zeitwerk:check"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Setup: Test DB", "env RAILS_ENV=test bin/rails db:create db:schema:load"
  step "Setup: Vite assets", "env RAILS_ENV=test bin/vite build"
  step "Tests: Rails", "env RAILS_ENV=test bin/rails test"
  step "Tests: System", "env RAILS_ENV=test bin/rails test:system"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  step "Docs: Swagger", "env RAILS_ENV=test bin/rails rswag:specs:swaggerize && git diff --exit-code swagger/v1/swagger.yaml"

  step "Frontend: Typecheck", "bun run check:svelte"
  step "Frontend: Lint", "bun run format:svelte:check"

  if success?
    step "Signoff: All systems go. Ready for merge and deploy."
  else
    failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  end
end
