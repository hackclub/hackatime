# AGENT.md - Rails Hackatime/Harbor Project

## Commands (via Docker Compose)
- **Tests**: `docker compose run web rails test` (all), `docker compose run web rails test test/models/user_test.rb` (single file), `docker compose run web rails test test/models/user_test.rb -n test_method_name` (single test) - Note: Limited test coverage
- **Lint**: `docker compose run web bundle exec rubocop` (check), `docker compose run web bundle exec rubocop -A` (auto-fix)
- **Console**: `docker compose run web rails c` (interactive console)
- **Server**: `docker compose run --service-ports web rails s -b 0.0.0.0` (development server)
- **Database**: `docker compose run web rails db:migrate`, `docker compose run web rails db:create`, `docker compose run web rails db:schema:load`, `docker compose run web rails db:seed`
- **Security**: `docker compose run web bundle exec brakeman` (security audit)
- **JS Security**: `docker compose run web bin/importmap audit` (JS dependency scan)
- **Zeitwerk**: `docker compose run web bin/rails zeitwerk:check` (autoloader check)

## CI/Testing Requirements
**Before marking any task complete, run ALL CI checks locally:**
1. `docker compose run web bundle exec rubocop` (lint check)
2. `docker compose run web bundle exec brakeman` (security scan)
3. `docker compose run web bin/importmap audit` (JS security)
4. `docker compose run web bin/rails zeitwerk:check` (autoloader)
5. `docker compose run web rails test` (full test suite)

## Docker Development
- **Interactive shell**: `docker compose run --service-ports web /bin/bash`
- **Initial setup**: `docker compose run web bin/rails db:create db:schema:load db:seed`

## Code Style (rubocop-rails-omakase)
- **Naming**: snake_case files/methods/vars, PascalCase classes, 2-space indent
- **Controllers**: Inherit `ApplicationController`, use `before_action`, strong params with `.permit()`
- **Models**: Inherit `ApplicationRecord`, extensive use of concerns/enums/scopes
- **Error Handling**: `rescue => e` + `Rails.logger.error`, graceful degradation in jobs
- **Imports**: Use `include` for concerns, `helper_method` for view access
- **API**: Namespace under `api/v1/`, structured JSON responses with status codes
- **Jobs**: GoodJob with 4 priority queues, inherit from `ApplicationJob`, concurrency control for cache jobs
- **Auth**: `ensure_authenticated!` for APIs, token via `Authorization` header or `?api_key=`
- **CSS**: Pico CSS framework + Uchu colors, component-specific CSS files, no Tailwind
