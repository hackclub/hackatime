# Hackatime architecture guide

This is a map of current ownership and invariants, not a proposed design. Follow
the linked source when behavior and this summary disagree.

## Sources of truth and derived state

| Domain | Source of truth | Derived / disposable state |
| --- | --- | --- |
| Identity | `users`, `email_addresses`, provider IDs and encrypted provider tokens | Session cookie |
| Coding activity | Canonical ClickHouse `heartbeat_store` and `heartbeat_aliases` | Query layouts, durations, dashboard/profile payloads, rollups, leaderboards, streaks, Rails caches |
| Heartbeat project identity | `heartbeats.project` | Project lists and project statistics |
| Per-user project settings | `project_repo_mappings` keyed by project name | Discovery retry/coalescing cache keys |
| Repository identity | Shared `repositories` row (`url`, host, owner, name) | Stars, languages, homepage, commit count, sync timestamps, imported commits |
| Async work | Pending/scheduled `good_jobs` rows and their serialized arguments | Finished execution history, process records, cron history and enqueue cache keys, subject to retention policy |

Do not write a rollup, duration, profile statistic, or cache as though it were
primary data. Change its input or the derivation, invalidate it, and let it be
rebuilt.

## 1. Rails request and Inertia/Svelte UI flow

1. Routes dispatch to Rails controllers. Browser controllers inherit
   [`ApplicationController`](../app/controllers/application_controller.rb),
   which supplies session identity, lockout enforcement, no-store headers,
   error reporting, PaperTrail attribution, and the user's time zone.
2. Inertia controllers inherit
   [`InertiaController`](../app/controllers/inertia_controller.rb). It shares
   layout props (navigation, flash, theme, CSRF token, footer and impersonation
   state) on every Inertia response. Controllers select a page with
   `render inertia: "Directory/Page", props: ...`; server props are the
   request's serialized boundary, not a second model layer.
3. [`inertia.ts`](../app/javascript/entrypoints/inertia.ts) resolves that name
   to `app/javascript/pages/Directory/Page.svelte` and wraps pages in
   `AppLayout.svelte`. Inertia `<Link>`, `<Form>` and `router` calls make later
   visits while Rails still owns routing, authorization, validation and writes.
4. Svelte pages own presentation and truly local/editable UI state. Keep domain
   calculations and authorization on the server. Shared props belong in
   `InertiaController`; page-specific props belong in the rendering controller.

Client route strings come from **js_from_routes**, not controller props or
hand-built URLs. Add a named route to `EXPORTED_ROUTES` in
[`js_from_routes.rb`](../config/initializers/js_from_routes.rb), regenerate, and
import the controller module from `app/javascript/api`. Call `.path()` with
path/query parameters. The generated directory is gitignored. The allowlist
exports named routes and nameless siblings for an already-exported controller;
it intentionally avoids exposing every Rails route.

Keep server-built URLs only when the client lacks required information (for
example, request host), or for external links. API-only controllers may inherit
`ActionController::API`; they are not part of the Inertia boundary.

## 2. Identity and authorization boundaries

### Browser identity

[`ApplicationController#current_user`](../app/controllers/application_controller.rb)
is exactly `User.find_by(id: session[:user_id])`. HCA, Slack, and single-use
email-link sign-in converge on a `User`; successful login resets the session
before assigning that ID. Slack and GitHub callback state is consumed and
compared with `secure_compare`; HCA currently does not use an OAuth state
nonce. Continuation URLs must be local paths (not `//...`). See
[`SessionsController`](../app/controllers/sessions_controller.rb).

[`EmailAddress`](../app/models/email_address.rb) owns normalized, globally
unique login addresses and their provenance. Provider/preserved addresses
cannot be unlinked, and a user cannot remove their last address. Provider IDs
and encrypted HCA/Slack/GitHub access tokens live on
[`User`](../app/models/user.rb); provider concerns own token exchange and remote
profile synchronization.

### API identities

* [`ApiKey`](../app/models/api_key.rb) is a user credential (UUIDv4 for WakaTime
  compatibility). The Hackatime-compatible controller accepts Bearer, Basic,
  or legacy `api_key` query input, resolves the key's user, then calls the
  ingestion service. It skips CSRF because it is token-authenticated; pending
  deletion blocks writes. See
  [`HackatimeController`](../app/controllers/api/hackatime/v1/hackatime_controller.rb).
* Doorkeeper is a separate delegated-user boundary. Its configured scopes are
  `profile` (default), `read`, and `admin`; validate token acceptability and
  required scopes, then load the resource owner. Ordinary OAuth/API access is
  denied for convicted or pending-deletion users via `api_access_restricted?`.
  Controllers that support ordinary user credentials declare their accepted
  API-key sources and OAuth scopes through
  [`UserApiAuthentication`](../app/controllers/concerns/user_api_authentication.rb).
  See [`doorkeeper.rb`](../config/initializers/doorkeeper.rb).
* Admin API credentials are either active `AdminApiKey`s or acceptable
  Doorkeeper `admin` tokens. OAuth admin access additionally requires a
  confidential, verified, admin-scoped application. The API boundary is
  [`Api::Admin::ApplicationController`](../app/controllers/api/admin/application_controller.rb).

### Admin authorization

Use [`AuthHelpers`](../app/controllers/concerns/auth_helpers.rb) and explicit
controller/model predicates; hiding a nav link is not authorization. `viewer`
can enter read-only admin surfaces and use admin API authentication, but general
browser admin writes require `admin`, `superadmin`, or `ultraadmin`.

The enum's stored numeric order is historical and **not privilege order**.
Use `User::ADMIN_LEVEL_RANK` and helpers. Effective order is
`default < viewer < admin < superadmin < ultraadmin`. Role/trust changes prohibit
self-action and require the actor to strictly outrank the target; only
superadmin+ changes admin levels, only ultraadmin grants ultraadmin, and a red
trust conviction requires superadmin+.

## 3. Heartbeat ingestion and duration semantics

Non-deleted ClickHouse heartbeat rows are authoritative activity when
`HEARTBEAT_STORE=clickhouse`, which is the default after cutover.
[`HeartbeatRepository`](../app/repositories/heartbeat_repository.rb) owns all
ClickHouse reads, exact timestamp filtering, canonical persistence and
replacement writes. `heartbeat_store` owns full payload and lifecycle state;
`heartbeat_aliases` owns canonical and legacy hash deduplication. PostgreSQL
provides only monotonic ID/version allocation, transient advisory locks and
coarse workflow status for transfer, deletion and JA4 operations. All direct
and imported writes should flow through
[`HeartbeatIngest`](../app/services/heartbeat_ingest.rb), which owns:

* accepted input normalization, sane epoch validation/repair, null/control
  cleanup, default categories, language and user-agent inference, source type,
  request metadata, and WakaTime placeholder handling;
* model validation before bulk insertion (bulk insertion deliberately bypasses
  callbacks), plus explicit callback-equivalent fields;
* deduplication and race-safe persistence; and
* scheduling rollup refresh and best-effort project mapping only after inserts.

`fields_hash` is the user-independent canonical identity of a normalized
heartbeat and includes its time and activity metadata listed by
`Heartbeat.indexed_attributes` (plus present AI attributes). The user remains
part of the alias primary key, so different accounts can own the same activity
while account transfers can deduplicate it exactly. Direct batches collapse
equal hashes. Import batches keep the latest row per hash and also check legacy
aliases so normalization changes do not duplicate old imports.
Admission persists a complete candidate before publishing aliases. A process
that dies at any later point can therefore be repaired entirely from
ClickHouse. `fields_hash` is intentionally absent from both query layouts and
their sorting keys.

Soft deletion is implemented by versioned replacement rows with `deleted_at`;
repository scopes hide those rows. Use `soft_delete` / `restore`, which update
the canonical store, independently acknowledge both query layouts and
invalidate rollups. Transfers retain higher-version source tombstones so a
delayed pre-transfer write cannot resurrect the old owner.

Duration is not stored. [`Heartbeatable`](../app/models/concerns/heartbeatable.rb)
derives it from ordered heartbeat timestamps. The default timeout is 2 minutes:

* the first heartbeat contributes zero;
* each later heartbeat contributes `min(current_time - previous_time, 120s)`;
* grouped duration partitions by the requested group, while
  `attributed_durations_by` computes globally ordered gaps and attributes each
  gap to the current heartbeat's bucket;
* `to_span` splits when a gap exceeds the timeout and caps the prior span's tail
  at the timeout; and
* boundary-aware calculations include the preceding heartbeat so a requested
  window does not incorrectly lose its opening interval.

Preserve deterministic ordering by `time, id`, timestamp validity filters, and
the timeout cap when adding reports. Eligibility scopes additionally distinguish
coding, browser activity and the `<<LAST_PROJECT>>` sentinel.

## 4. Dashboard/profile rollups and cache policy

[`DashboardStats`](../app/services/dashboard_stats.rb) is the read facade. An
unfiltered all-time dashboard can use `dashboard_rollups`; filtered/custom time
ranges query heartbeats. A missing aggregate total falls back to live
calculation and schedules a refresh. A dirty or stale aggregate total is served
while refresh is scheduled. Invalid activity-graph/today fragments and
malformed filter options fall back to live calculation and schedule refresh.
The assembled filtered dashboard payload has a disposable five-minute cache.

[`DashboardRollupRefreshService`](../app/services/dashboard_rollup_refresh_service.rb)
rebuilds totals, dimensions, weekly projects, project details, filter options,
activity graph and today's stats from the user's non-archived heartbeats. It
atomically replaces all of one user's rows in a transaction. The refresh job
increments a durable generation on the user before enqueue, coalesces scheduling
with a cache key, and uses a per-user GoodJob concurrency limit. It only marks
the captured generation refreshed, so a mutation during the query schedules
another refresh. A recurring sweep recovers dirty generations after cache
eviction or a process crash. Heartbeat commits, soft-delete/
restore, timezone changes, and project archive changes schedule refreshes.

[`ProfileStatsService`](../app/services/profile_stats_service.rb) is a thin
projection of `DashboardStats`, including OG-image totals. It has no independent
authoritative statistic. With ClickHouse enabled these product surfaces query
the repository directly; project durations, filter options, activity graphs and
streaks are not cached. The PostgreSQL rollup refresh job is disabled. Homepage
totals use one exact ClickHouse query, with archived project pairs supplied from
relational metadata. Change shared duration/snapshot logic below both
dashboard and profile rather than patching profile output independently.

## 5. Projects, repositories and repo hosts

[`ProjectRepoMapping`](../app/models/project_repo_mapping.rb) owns a user's
repository association, archive state and sharing state keyed by a heartbeat
project name. The heartbeat remains authoritative for the project identity and
a mapping may not exist. Archiving affects dashboard scope and invalidates
rollups. Ingestion asynchronously attempts mapping for new non-sentinel project
names; discovery currently searches the linked GitHub user and organizations.

[`Repository`](../app/models/repository.rb) is shared by URL and owns parsed
host/owner/name plus synchronized host metadata. Mapping callbacks create/reuse
it and trigger metadata/commit work. A mapping is user-specific; a repository
is not. Do not put user preferences on `Repository` or shared host metadata on
the mapping.

External repository calls belong behind
[`RepoHost::ServiceFactory`](../app/services/repo_host/service_factory.rb) and
[`BaseService`](../app/services/repo_host/base_service.rb). Only GitHub is
supported today; [`GithubService`](../app/services/repo_host/github_service.rb)
owns GitHub headers, existence checks, metadata requests and rate-limit/error
translation. Extending hosts requires factory/host validation and a service
implementation, plus updating jobs that currently contain GitHub-specific
discovery/event logic. Several periodic repository scan/sync cron entries are
currently disabled; do not assume they run.

## 6. GoodJob, mail and Slack

All jobs inherit [`ApplicationJob`](../app/jobs/application_job.rb), which
provides shared error-reporting helpers and discards deserialization and
concurrency-limit failures.
[`good_job.rb`](../config/initializers/good_job.rb) is the queue/cron source of
truth: development runs async threads, non-development expects external
workers, and cron is production-only. Choose a queue by latency/ownership; do
not perform slow remote work in request controllers merely because development
can execute jobs in-process.

Action Mailer owns message composition/delivery. Production SMTP configuration
and the `latency_10s` `deliver_later` queue live in
[`production.rb`](../config/environments/production.rb). Some jobs intentionally
call `deliver_now` *inside an already-queued job*; preserve that boundary unless
changing retry/queue semantics deliberately.

Slack has three boundaries: OAuth/provider identity in the user concerns,
signed command ingress in [`SlackController`](../app/controllers/slack_controller.rb),
and queued command/profile/status work. Outside development, commands require a
valid Slack HMAC signature and timestamp within five minutes. Remote API calls,
token choice and typed rate-limit behavior live in
[`SlackIntegration`](../app/models/concerns/slack_integration.rb); controllers
should authenticate, validate and enqueue.

## 7. Time zones, transactions and concurrency

Heartbeat `time` is Unix epoch time. Calendar concepts (today, week, streak,
activity dates) use the validated `User#timezone`. Browser requests run inside
`Time.use_zone(current_user.timezone)`; services/jobs without that wrapper must
use `Time.use_zone` explicitly. SQL day grouping converts epochs with the user
timezone and falls back to UTC only where the reporting code explicitly guards
invalid legacy data. A timezone change schedules a PostgreSQL rollup refresh;
ClickHouse-backed activity reads use the current timezone directly.

Use database constraints/upserts for cross-process correctness, transactions
for multi-row replacement, `after_commit` for derived work, and GoodJob
concurrency plus cache coalescing for expensive idempotent refreshes. Rails
cache alone is an optimization, not a lock or source of truth. In particular,
keep heartbeat dedup race-safe and rollup replacement atomic.

## Where should this change go?

| Change | Put it here |
| --- | --- |
| Parse/normalize/accept heartbeat input | `HeartbeatIngest`; controller only permits/authenticates/responds |
| Change activity or gap math | `Heartbeatable` / shared snapshot query code, then verify every consumer |
| Add dashboard/profile statistic | `DashboardData::Snapshots` + `DashboardStats`; add rollup dimension only if appropriate |
| Change page data or validation | Rails controller/service/model; serialize minimal Inertia props |
| Change page interaction/presentation | Svelte page/component; use Inertia primitives |
| Add a frontend Rails URL | Rails route + `js_from_routes` allowlist + generated helper import |
| Add browser/admin/API authorization | Existing auth concern/controller boundary and model capability predicate |
| Change sign-in/provider identity | `SessionsController` plus the relevant user OAuth/provider concern |
| Change project archive/share/user mapping | `ProjectRepoMapping` and its controller/job |
| Change shared repository metadata/API calls | `Repository` + `RepoHost` service + sync job |
| Add slow, scheduled or retryable work | `ApplicationJob` subclass and GoodJob queue/cron config as needed |
| Compose/send mail | Mailer; enqueue from the owning lifecycle/job |
| Handle Slack command/API behavior | Verified ingress controller, Slack concern/client boundary, then job |
| Change a calendar-day report | Explicit user-zone service/query; invalidate timezone-sensitive derived data |
