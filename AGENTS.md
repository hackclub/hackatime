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
- **Zeitwerk**: `docker compose exec web bin/rails zeitwerk:check` (autoloader check)
- **Swagger**: `docker compose exec web bin/rails rswag:specs:swaggerize` (generate API docs)

## Bug Fixes

Always reproduce a reported bug before changing code. Confirm the failure using the narrowest reliable reproduction and record the current behaviour so the fix can be verified against it. If reproduction is impossible because required data, credentials or services are unavailable, state that clearly before proceeding.

After fixing the bug, rerun the original reproduction as well as the regression test. Test externally visible behaviour and durable state rather than private implementation details. Prefer real models and database behaviour over mocks.

## Engineering Decisions

Start with the smallest correct change in the current owner. Before editing, identify the source of truth and the invariant being protected. Read [the architecture guide](ARCHITECTURE.md) when a change crosses subsystem boundaries.

### Rails ownership ladder

Put behaviour in the narrowest layer that naturally owns it:

1. **Controller**: HTTP concerns, authentication, authorisation, strong parameters and response selection.
2. **Model**: invariants, state transitions and behaviour owned by persisted data.
3. **Scope or query object**: reusable data retrieval. Introduce a query object only when scopes stop composing clearly.
4. **Job**: delayed or retryable execution. Jobs must be idempotent.
5. **Service object**: an operation that genuinely coordinates multiple models, external systems or transaction boundaries.
6. **Concern**: a cohesive capability, not a place to hide unrelated model or controller size.

Do not create a service object merely to make a controller or model shorter. Extract an operation only when it has a coherent responsibility that does not naturally belong to one model.

### Correctness rules

- Use database constraints for integrity and model validations for useful feedback.
- Put related writes in a transaction. Do not make network calls inside that transaction.
- Enqueue external side effects after commit where practical.
- Make GoodJob jobs safe to retry without duplicate records, notifications or state transitions.
- Treat caches, dashboard rollups and summaries as derived data. Identify and update the source of truth rather than repairing derived output.
- Check authorisation separately from authentication.
- Use bang methods when failure must abort the operation.
- Do not use callbacks for workflows spanning multiple models or external systems.
- Rescue only errors the code can meaningfully handle and rescue the narrowest exception class possible. Log enough context and re-raise unexpected failures. Never report success after a partial write.
- Check query count and eager loading when rendering collections.
- Store timestamps in UTC. For calendar boundaries and presentation, use `Time.current` or `Date.current` inside the user's `Time.use_zone(user.timezone)` context. Background jobs that calculate user-local calendar boundaries must establish that context explicitly.
- Use `Process.clock_gettime(Process::CLOCK_MONOTONIC)` rather than wall-clock time to measure elapsed execution time.

### When to zoom out

Zoom out only when there is evidence that the current ownership boundary prevents a correct implementation. Evidence includes:

- The same business rule must change in three or more places.
- Two modules disagree about the source of truth.
- A correct operation cannot be made atomic within the current boundary.
- Callbacks, jobs or cache refreshes repeatedly compensate for unclear ownership.
- A collection of booleans represents an undocumented state machine.
- Retry, concurrency or ordering bugs recur because state is implicit.
- A public contract repeatedly leaks internal implementation details.
- Tests require extensive stubbing because responsibilities cannot be exercised independently.

Do not re-architect merely because a class is long but cohesive, a method gained one branch, two snippets look similar, an abstraction feels inelegant or a hypothetical future caller might need flexibility. Do not add an abstraction with only one caller unless it creates a clear ownership boundary or protects a critical invariant.

Use this escalation order:

1. Fix the bug in the existing owner.
2. Strengthen the owner's invariant or API.
3. Remove proven duplication around that invariant.
4. Extract one coherent responsibility.
5. Rework the subsystem boundary only when the earlier steps cannot make it correct.

Before a broad redesign, state the invariant, why the current owner cannot protect it, the smallest viable new boundary, migration and rollback risks and how behaviour will be preserved. Get user agreement on the plan unless the redesign is required to resolve an active correctness or security issue.

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
- **Reset test database**: `docker compose exec web env RAILS_ENV=test bin/rails db:drop db:create db:schema:load`
- **Cleanup**: Run commands with the `--remove-orphans` flag to remove unused containers and images

### Amp portal server

The Amp portal runs Rails in the dedicated `portal` Compose profile while the `web` container remains available for commands. Keep the portal process attached to `docker compose up`; do not change it back to `docker compose exec`, because stopping the outer exec process can orphan Puma inside the container. Use `amp orb service restart hackatime` after changing the portal service configuration.

Orb setup prebuilds the Vite client bundle so the first portal request does not block on a build. After changing frontend source, run `docker compose exec web bin/vite build` before asking the user to review the portal; otherwise their first request can spend several seconds compiling assets.

## Development Authentication

Development-only endpoints are available to bypass OAuth when working locally or in an Amp orb:

- `GET /__dev` lists the available development endpoints.
- `GET /__dev/log-me-in/<email>` signs the browser in as the local user with that email. Use `/__dev/log-me-in/test@example.com` for the seeded development user.
- `GET /__dev/log-me-out` signs the browser out.

These endpoints are only available in the development environment.

## Git Practices

- **NEVER commit `config/database.yml`** unless explicitly asked to - contains sensitive local/production database credentials
- **NEVER use `git add .`** - always add files individually to avoid accidentally committing unwanted files
- Use `git add <specific-file>` or `git add <directory>/` for targeted commits

## Pull Requests

- Always use the GitHub PR template at `.github/pull_request_template.md` when creating a PR.
- Write PR titles and descriptions in British English.
- Never use em dashes or en dashes.
- Never use Oxford commas.
- Do not list commands you ran in the PR description.
- Do not mention tests passing in the PR description.
- Bias towards including screenshots or other media, particularly for visual changes.
- Keep descriptions short and simple while still explaining the problem and the useful parts of the change. Avoid waffle.

## Code Style (rubocop-rails-omakase)

- **Naming**: snake_case files/methods/vars, PascalCase classes, 2-space indent
- **Controllers**: Inherit `ApplicationController`, use `before_action`, strong params with `.permit()`
- **Models**: Inherit `ApplicationRecord`; keep domain behaviour with the model that owns the data; use enums and composable scopes where they clarify the domain
- **Concerns**: Use concerns only for cohesive capabilities with a clear name, not as miscellaneous storage
- **Error Handling**: Rescue specific failures that can be handled meaningfully; log context and let unexpected failures surface
- **Imports**: Use `include` for concerns, `helper_method` for view access
- **API**: Namespace under `api/v1/`, structured JSON responses with status codes
- **Jobs**: GoodJob with 4 priority queues, inherit from `ApplicationJob`, concurrency control for cache jobs
- **Auth**: `ensure_authenticated!` for APIs, token via `Authorization` header or `?api_key=`
- **CSS**: Using Tailwind CSS, no inline styles, use utility classes. We define some custom classes in `config/tailwind.config.js` and `app/assets/tailwind/application.css`.

## Inertia Components

On Inertia pages, use the `<Button />` component for buttons, not `<button>` tags.

When linking to an Inertia page, use the `<Link />` component instead of `<a>` tags.

## Svelte 5 Runes

Don't mirror Inertia props into local `$state` with a `$effect` that just copies them back **for read-only display values**. Props are already reactive — bind to `user.foo` directly (or pass it as `value={user.foo}`) instead of introducing a redundant `let foo = $state(user.foo)` + `$effect(() => { foo = user.foo })`. Only introduce local `$state` when you actually need state that diverges from the prop.

**Exception — editable form state for Inertia forms.** When the user edits the value locally (`bind:value`, `bind:group`, `bind:checked`), you legitimately need local `$state`, *and* you need a `$effect` to re-sync from props after a server validation error. On 422, Rails re-renders the same component with updated `application`/`form` props; if you only initialize once (`let foo = $state(application.bar)` or `let foo = $state(untrack(() => application.bar))`), the form fields will not reflect server-normalized values on re-render. Keep the `$effect` here — this is the legitimate use case, not the anti-pattern.

If `svelte-check` warns `state_referenced_locally` on a `$state(prop)` initializer that you genuinely want to read once (e.g. a tab-default chosen from a prop that never changes after mount), wrap the initializer in `untrack(() => ...)` from `svelte` to silence it. Do **not** use `untrack` to silence the warning on editable form fields — that hides a real bug; restore the `$effect` instead.

For computed values derived from props (`const x = prop === "a" ? ... : ...`), use `$derived(...)` instead of a bare `const` — otherwise `state_referenced_locally` will fire and the value won't update if the prop changes.

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

## Default theme

To change the default theme, update it in **two places**:

1. `app/models/concerns/user_theme_configuration.rb` — `DEFAULT_THEME` constant (controls the model default and `theme_metadata` fallback)
2. `app/javascript/utils.ts` — `DEFAULT_THEME` export (used by `MarketingLayout.svelte` for unauthenticated pages, and `Appearance.svelte` as the pre-load fallback)

Valid theme values are the keys of the `enum :theme` in `app/models/user.rb`.

## Searching for users
- Need to show users to a human (search UI, picker)? → `fuzzy_ranked_search`
- Need to find IDs to filter something else by? → `search_identity`
