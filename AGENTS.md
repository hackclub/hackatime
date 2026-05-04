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

## Authorization (Pundit)

Role-based authorization lives in `app/policies/`. The role hierarchy is
strict-linear: **ultraadmin ⊇ superadmin ⊇ admin ⊇ viewer ⊇ default**.

`ApplicationPolicy` defines the canonical predicates (`ultraadmin?`,
`superadmin?`, `admin?`, `viewer?`, `any_admin?`, plus `red?` /
`signed_in?`). Each tier `||`s up to the next, so a higher tier passes
every gate a lower tier does. Always reach for these predicates inside
policy methods rather than calling `user.admin_level_*?` directly.

Admin web controllers inherit from `Admin::BaseController`, which
applies `before_action :authorize_admin_action!` automatically (opt-out
model — every action is gated unless explicitly skipped). To add a new
admin controller, just declare the `authorization_record`:

```ruby
class Admin::WidgetsController < Admin::BaseController
  self.authorization_record = ->(c) { c.instance_variable_get(:@widget) || Widget }

  # Use prepend_before_action so the loader runs BEFORE the inherited
  # authorize_admin_action! callback. (A plain before_action would run
  # after, which means the lambda above would still see a nil @widget
  # and authorize against the class instead of the instance.)
  prepend_before_action :set_widget, only: [ :show, :update ]
end
```

The `authorize_admin_action!` helper calls `authorize(record, "#{action_name}?")`
and rescues `Pundit::NotAuthorizedError` into the legacy "redirect to
root with alert" UX. Define the matching predicates in
`app/policies/widget_policy.rb`.

If a specific action needs custom authorization (e.g. rules that depend
on the target record's relationship to `current_user`), skip the
default and authorize inline:

```ruby
skip_before_action :authorize_admin_action!, only: [ :update ]

def update
  return redirect_to(...) unless policy(@target).my_custom?
  # ...
end
```

For headless policies (no AR record), pass a symbol:
`authorize :admin, :access?` resolves `AdminPolicy#access?`.

Test new policies under `test/policies/<name>_policy_test.rb` against
the role matrix (see `policy_test_helper.rb`).

## Inertia Components

On Inertia pages, use the `<Button />` component for buttons, not `<button>` tags.

When linking to an Inertia page, use the `<Link />` component instead of `<a>` tags.

## Svelte 5 Runes

Don't mirror Inertia props into local `$state` with a `$effect` that just copies them back. Props are already reactive — bind to `user.foo` directly (or pass it as `value={user.foo}`) instead of introducing a redundant `let foo = $state(user.foo)` + `$effect(() => { foo = user.foo })`. Only introduce local `$state` when you actually need state that diverges from the prop.

## Path helpers (js_from_routes)

We use [js_from_routes](https://js-from-routes.netlify.app) to generate TypeScript path helpers from Rails routes, instead of passing `*_path` strings down as Inertia props. **Don't pass paths as props** — derive them on the client.

- **Don't:**
  ```ruby
  render inertia: "Foo", props: { update_path: my_foo_update_path }
  ```
  ```svelte
  <Form action={update_path} method="patch">
  ```
- **Do:**
  ```ruby
  render inertia: "Foo", props: {}
  ```
  ```svelte
  <script lang="ts">
    import { fooThings } from "../../api";
    const updatePath = fooThings.update.path();
  </script>
  <Form action={updatePath} method="patch">
  ```

For a route with URL params, pass them to `.path()`:

```ts
fooThings.update.path({ id: 1 }); // -> "/foo_things/1"
fooThings.update.path({ query: { from: "x" } }); // -> "/foo_things?from=x"
```

### Adding a new path helper

1. Add the route's `as:` name to `EXPORTED_ROUTES` in `config/initializers/js_from_routes.rb`. We use an explicit allowlist (not `defaults export: true`) so the generated `app/javascript/api/` stays small and predictable.
2. In dev, refresh the page (Rails reloader regenerates) or run `docker compose exec web bin/rake js_from_routes:generate`. Force regeneration with `JS_FROM_ROUTES_FORCE=true`.
3. Import from `app/javascript/api/<Namespace>Api.ts` (one file per controller). All helpers are also re-exported from `app/javascript/api/index.ts`.

### When to keep paths as server-built props

- The path needs the request host (e.g. `share_url: profile_project_url(...)` for clipboard copy/link sharing).
- The path is computed from data the client doesn't have (e.g. `LeaderboardPageCache` builds per-row `profile_path` server-side and caches it).
- The path is purely external (GitHub edit links, Slack channels, etc.) — those aren't Rails routes anyway.

### Generated files are NOT checked in

Files under `app/javascript/api/` are gitignored and regenerated on every build:

- **Dev**: `entrypoint.dev.sh` regenerates on container start, and the Rails reloader regenerates on subsequent route changes.
- **Production Docker build**: regenerated in `Dockerfile` before `assets:precompile`.
- **CI**: regenerated in the `frontend` and `test_system` jobs before Vite/svelte-check run; the `test` job triggers regeneration via Rails boot.

After adding a route to `EXPORTED_ROUTES`, just refresh the page (or run `docker compose exec web bin/rake js_from_routes:generate`) — there's nothing to commit.
