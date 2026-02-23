# AGENTS.md for Hackatime

_You MUST read the [development guide](DEVELOPMENT.md) before starting. If you cannot read it, please ask for help._

We do development using docker-compose. Run `docker compose ps` to see if the dev server is running. If it is, then you can restart the dev server with `touch tmp/restart.txt` (but do not do this unless you added/removed a gem). If not, bring the containers up first with `docker compose up -d`.

**IMPORTANT**: Always use `docker compose exec` (not `run`) to execute commands in the existing container. `run` creates a new container each time; `exec` reuses the running one.

## Commands (via Docker Compose)

- **Tests**: `docker compose exec web rails test` (all), `docker compose exec web rails test test/models/user_test.rb` (single file), `docker compose exec web rails test test/models/user_test.rb -n test_method_name` (single test) - Note: Limited test coverage
- **Lint**: `docker compose exec web bundle exec rubocop` (check), `docker compose exec web bundle exec rubocop -A` (auto-fix)
- **Console**: `docker compose exec web rails c` (interactive console)
- **Server**: `docker compose exec web rails s -b 0.0.0.0` (development server)
- **Database**: `docker compose exec web rails db:migrate`, `docker compose exec web rails db:create`, `docker compose exec web rails db:schema:load`, `docker compose exec web rails db:seed`
- **Security**: `docker compose exec web bundle exec brakeman` (security audit)
- **JS Security**: `docker compose exec web bin/importmap audit` (JS dependency scan)
- **Zeitwerk**: `docker compose exec web bin/rails zeitwerk:check` (autoloader check)
- **Swagger**: `docker compose exec web bin/rails rswag:specs:swaggerize` (generate API docs)

## CI/Testing Requirements

Before marking any task complete, you MUST check `config/ci.rb` and manually run the checks in that file which are relevant to your changes (with `docker compose exec`.)

Skip running checks which aren't relevant to your changes. However, at the very end of feature development, recommend the user to run all checks. If they say yes, run `docker compose exec web bin/ci` to run them all.

## API Documentation

- **Specs**: All new API endpoints MUST include Rswag specs in `spec/requests/api/...`.
- **Generation**: After changing specs, run `bundle exec rake rswag:specs:swaggerize` to update `swagger/v1/swagger.yaml`.
- **Validation**: CI will fail if `swagger.yaml` is out of sync with the specs (meaning you forgot to run the generation command).

## Docker Development

- **Start containers**: `docker compose up -d` (must be running before using `exec`)
- **Interactive shell**: `docker compose exec web /bin/bash`
- **Initial setup**: `docker compose exec web bin/rails db:create db:schema:load db:seed`
- **Cleanup**: Run commands with the `--remove-orphans` flag to remove unused containers and images

## Git Practices

- **NEVER commit `config/database.yml`** unless explicitly asked to - contains sensitive local/production database credentials
- **NEVER use `git add .`** - always add files individually to avoid accidentally committing unwanted files
- Use `git add <specific-file>` or `git add <directory>/` for targeted commits

## Code Style (rubocop-rails-omakase)

- **Naming**: snake_case files/methods/vars, PascalCase classes, 2-space indent
- **Controllers**: Inherit `ApplicationController`, use `before_action`, strong params with `.permit()`
- **Models**: Inherit `ApplicationRecord`, extensive use of concerns/enums/scopes
- **Error Handling**: `rescue => e` + `Rails.logger.error`, graceful degradation in jobs
- **Imports**: Use `include` for concerns, `helper_method` for view access
- **API**: Namespace under `api/v1/`, structured JSON responses with status codes
- **Jobs**: GoodJob with 4 priority queues, inherit from `ApplicationJob`, concurrency control for cache jobs
- **Auth**: `ensure_authenticated!` for APIs, token via `Authorization` header or `?api_key=`
- **CSS**: Using Tailwind CSS, no inline styles, use utility classes. We define some custom classes in `config/tailwind.config.js` and `app/assets/tailwind/application.css`.

## Inertia Components

On Inertia pages, use the `<Button />` component for buttons, not `<button>` tags.

When linking to an Inertia page, use the `<Link />` component instead of `<a>` tags.
