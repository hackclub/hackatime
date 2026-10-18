# Hackatime architecture guide

This is a map of current ownership and invariants, not a proposed design. Follow
the linked source when behavior and this summary disagree.

## Sources of truth and derived state

| Domain | Source of truth | Derived / disposable state |
| --- | --- | --- |
| Identity | `users`, `email_addresses`, provider IDs and encrypted provider tokens | Session cookie |
| Coding activity | Non-deleted `heartbeats` | Durations, dashboard/profile payloads, rollups, leaderboards, streaks, Rails caches |
| Heartbeat project identity | `heartbeats.project` | Project lists and project statistics |
| Per-user project settings | `project_repo_mappings` keyed by project name | Discovery retry/coalescing cache keys |
| Repository identity | Shared `repositories` row (`url`, host, owner, name) | Stars, languages, homepage, commit count, sync timestamps, imported commits |
| Async work | Pending/scheduled `good_jobs` rows and their serialized arguments | Finished execution history, process records, cron history and enqueue cache keys, subject to retention policy |

Do not write a rollup, duration, profile statistic, or cache as though it were
primary data. Change its input or the derivation, invalidate it, and let it be
rebuilt.

## 1. Rails request and Inertia/Svelte UI flow

1. Routes dispatch to Rails controllers. Browser controllers inherit
   [`ApplicationController`](app/controllers/application_controller.rb),
   which supplies session identity, lockout enforcement, no-store headers,
   error reporting, PaperTrail attribution, and the user's time zone.
2. Inertia controllers inherit
   [`InertiaController`](app/controllers/inertia_controller.rb). It shares
   layout props (navigation, flash, theme, CSRF token, footer and impersonation
   state) on every Inertia response. Controllers select a page with
   `render inertia: "Directory/Page", props: ...`; server props are the
   request's serialized boundary, not a second model layer.
3. [`inertia.ts`](app/javascript/entrypoints/inertia.ts) resolves that name
   to `app/javascript/pages/Directory/Page.svelte` and wraps pages in
   `AppLayout.svelte`. Inertia `<Link>`, `<Form>` and `router` calls make later
   visits while Rails still owns routing, authorization, validation and writes.
4. Svelte pages own presentation and truly local/editable UI state. Keep domain
   calculations and authorization on the server. Shared props belong in
   `InertiaController`; page-specific props belong in the rendering controller.

Client route strings come from **js_from_routes**, not controller props or
hand-built URLs. Mark the route with `export: true` in
[`config/routes.rb`](config/routes.rb), regenerate, and
import the controller module from `app/javascript/api`. Call `.path()` with
path/query parameters. The generated directory is gitignored. Only marked
routes are exported; it intentionally avoids exposing every Rails route.

Keep server-built URLs only when the client lacks required information (for
example, request host), or for external links. API-only controllers may inherit
`ActionController::API`; they are not part of the Inertia boundary.

## 2. Identity and authorization boundaries

### Browser identity

[`ApplicationController#current_user`](app/controllers/application_controller.rb)
is exactly `User.find_by(id: session[:user_id])`. HCA, Slack, and single-use
email-link sign-in converge on a `User`; successful login resets the session
before assigning that ID. Slack and GitHub callback state is consumed and
compared with `secure_compare`; HCA currently does not use an OAuth state
nonce. Continuation URLs must be local paths (not `//...`). See
[`SessionsController`](app/controllers/sessions_controller.rb).

[`EmailAddress`](app/models/email_address.rb) owns normalized, globally
unique login addresses and their provenance. Provider/preserved addresses
cannot be unlinked, and a user cannot remove their last address. Provider IDs
and encrypted HCA/Slack/GitHub access tokens live on
[`User`](app/models/user.rb); provider concerns own token exchange and remote
profile synchronization.

### API identities

* [`ApiKey`](app/models/api_key.rb) is a user credential (UUIDv4 for WakaTime
  compatibility). The Hackatime-compatible controller accepts Bearer, Basic,
  or legacy `api_key` query input, resolves the key's user, then calls the
  ingestion service. It skips CSRF because it is token-authenticated; pending
  deletion blocks writes. See
  [`HackatimeController`](app/controllers/api/hackatime/v1/hackatime_controller.rb).
* Doorkeeper is a separate delegated-user boundary. Its configured scopes are
  `profile` (default), `read`, and `admin`; validate token acceptability and
  required scopes, then load the resource owner. Ordinary OAuth/API access is
  denied for convicted or pending-deletion users via `api_access_restricted?`.
  Controllers that support ordinary user credentials declare their accepted
  API-key sources and OAuth scopes through
  [`UserApiAuthentication`](app/controllers/concerns/user_api_authentication.rb).
  See [`doorkeeper.rb`](config/initializers/doorkeeper.rb).
* Admin API credentials are either active `AdminApiKey`s or acceptable
  Doorkeeper `admin` tokens. OAuth admin access additionally requires a
  confidential, verified, admin-scoped application. The API boundary is
  [`Api::Admin::ApplicationController`](app/controllers/api/admin/application_controller.rb).

### Admin authorization

Use [`AuthHelpers`](app/controllers/concerns/auth_helpers.rb) and explicit
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

Non-deleted [`Heartbeat`](app/models/heartbeat.rb) rows are authoritative
activity. All direct and imported writes should flow through
[`HeartbeatIngest`](app/services/heartbeat_ingest.rb), which owns:

* accepted input normalization, sane epoch validation/repair, null/control
  cleanup, default categories, language and user-agent inference, source type,
  request metadata, and WakaTime placeholder handling;
* model validation before bulk insertion (bulk insertion deliberately bypasses
  callbacks), plus explicit callback-equivalent fields;
* deduplication and race-safe persistence; and
* scheduling rollup refresh and best-effort project mapping only after inserts.

`fields_hash` is the persisted identity of a normalized heartbeat and includes
the user, time and activity metadata listed by
`Heartbeat.indexed_attributes` (plus present AI attributes). Direct batches
collapse equal hashes; `insert_all ... unique_by` lets the database settle
cross-request races, then ingestion fetches the winning row. Import batches
keep the latest row per hash and also check legacy hashes so normalization
changes do not duplicate old imports. Uniqueness is the partial
`fields_hash` index over non-deleted rows.

Soft deletion is implemented by `deleted_at`; the model's default scope hides
those rows. Use `soft_delete` / `restore`, which also invalidate rollups.

[`HeartbeatExclusion`](app/models/heartbeat_exclusion.rb) rules (admin poisons,
project deletions) hide heartbeats without deleting them. A second default scope
applies them to every model read. Raw SQL must include
`HeartbeatExclusion::VISIBLE_SQL`; code that intentionally needs hidden rows uses
`Heartbeat.with_excluded` or embeds `HeartbeatExclusion::INCLUDE_HIDDEN_COMMENT`.
The test suite raises on heartbeat SQL that does neither, including writes that
would silently skip hidden rows. Per-user caches of heartbeat-derived data must
include `User#heartbeat_cache_version` in their keys so rule changes bust them.

Duration is not stored. [`Heartbeatable`](app/models/concerns/heartbeatable.rb)
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

## 4. Dashboard/profile rollups and caches

[`DashboardStats`](app/services/dashboard_stats.rb) is the read facade. An
unfiltered all-time dashboard can use `dashboard_rollups`; filtered/custom time
ranges query heartbeats. A missing aggregate total falls back to live
calculation and schedules a refresh. A dirty or stale aggregate total is served
while refresh is scheduled. Invalid activity-graph/today fragments and
malformed filter options fall back to live calculation and schedule refresh.
Short Rails caches (currently 1/5/15 minutes depending on fragment) are also
disposable.

[`DashboardRollupRefreshService`](app/services/dashboard_rollup_refresh_service.rb)
rebuilds totals, dimensions, weekly projects, project details, filter options,
activity graph and today's stats from the user's non-archived heartbeats. It
atomically replaces all of one user's rows in a transaction. The refresh job
marks the user dirty before enqueue, coalesces scheduling with a cache key, and
uses a per-user GoodJob concurrency limit. Heartbeat commits, soft-delete/
restore, timezone changes, and project archive changes schedule refreshes.

[`ProfileStatsService`](app/services/profile_stats_service.rb) is a thin
projection of `DashboardStats`, including OG-image totals. It has no independent
authoritative statistic. Change shared duration/snapshot logic below both
dashboard and profile rather than patching profile output independently.

## 5. Projects, repositories and repo hosts

[`ProjectRepoMapping`](app/models/project_repo_mapping.rb) owns a user's
repository association, archive state and sharing state keyed by a heartbeat
project name. The heartbeat remains authoritative for the project identity and
a mapping may not exist. Archiving affects dashboard scope and invalidates
rollups. Ingestion asynchronously attempts mapping for new non-sentinel project
names; discovery currently searches the linked GitHub user and organizations.

[`Repository`](app/models/repository.rb) is shared by URL and owns parsed
host/owner/name plus synchronized host metadata. Mapping callbacks create/reuse
it and trigger metadata/commit work. A mapping is user-specific; a repository
is not. Do not put user preferences on `Repository` or shared host metadata on
the mapping.

External repository calls belong behind
[`RepoHost::ServiceFactory`](app/services/repo_host/service_factory.rb) and
[`BaseService`](app/services/repo_host/base_service.rb). Only GitHub is
supported today; [`GithubService`](app/services/repo_host/github_service.rb)
owns GitHub headers, existence checks, metadata requests and rate-limit/error
translation. Extending hosts requires factory/host validation and a service
implementation, plus updating jobs that currently contain GitHub-specific
discovery logic. Several periodic repository scan/sync cron entries are
currently disabled; do not assume they run.

Every GitHub REST request goes through `RepoHost::GithubService.get`. It logs a
`[GitHubAPI]` line with the endpoint template, status and remaining allowance,
but never the token or repository name. After a primary or secondary rate limit
it raises `RepoHost::RateLimitError` and refuses to use that token again until
GitHub's reset time. Secondary limits are also reported to Sentry. Background
calls use the user's own token, which shares that user's 5,000 requests per
hour with their other tools, so keep them bounded.
Background sync is off unless the `github_sync` Flipper flag is enabled. While
it is off, `GithubApiJob` jobs finish without calling GitHub and no mapping
lookups are queued. Sign-in and manual mapping checks are not affected.
`AttemptProjectRepoMappingJob` only maps public repositories. A repository in
the user's own namespace wins. An organisation repository is only mapped when
the user has commits in it and no other organisation has one that also
qualifies. Any existing mapping row, including one with a blank URL, stops
automatic mapping for that project, so user edits are never overwritten. The
job remembers a finished lookup for 14 days, caches organisation lists for a day and spends at
most 50 GitHub requests per user per day. These counters live in Solid Cache,
which can evict entries early, so treat them as throttles rather than durable
state. A mapping whose repository URL is set or changed queues one commit pull
and one metadata sync after commit. Existing mappings are kept fresh by the
hourly `ReconcileActiveRepositoriesJob`. Each run picks at most 100
repositories whose mapped project had heartbeats in the last day and that were
last synced over 6 hours ago, oldest first. It queues a metadata sync for each
and at most 100 commit pulls for their active coders. Each job gets its own
15 second slot. A sync that gets no metadata (missing, private or no usable
token) still updates `last_synced_at`, so the same repository is not retried
every hour. A GitHub 5xx raises `RepoHost::ServerError` instead: the job retries
twice and then stops without writing anything, so the repository stays due. The old
`SyncStaleRepoMetadataJob`, which re-queued every stale repository daily, stays
disabled.

GitHub data never decides leaderboard eligibility. Eligibility only needs a
linked `github_uid`. A rejected token clears `github_access_token` and keeps
`github_uid`, so missing or stale GitHub data cannot hide a user.

Repository sync only handles public repositories. Automatic mapping skips
private repositories, and metadata sync stores nothing for them. The GitHub
sign-in app needs no permission or webhook changes for the current code. Its
owner should check that the only repository permission is the mandatory
Metadata (read) permission, and leave the webhook inactive. Do not add the
Contents permission or push webhooks: GitHub only delivers push events to apps
with Contents access, and that access covers every repository an installer
selects, private ones included. GitHub has no public-only alternative.

## 6. GoodJob, mail and Slack

All jobs inherit [`ApplicationJob`](app/jobs/application_job.rb), which
provides shared error-reporting helpers and discards deserialization and
concurrency-limit failures.
[`good_job.rb`](config/initializers/good_job.rb) is the queue/cron source of
truth: development runs async threads, non-development expects external
workers, and cron is production-only. Choose a queue by latency/ownership; do
not perform slow remote work in request controllers merely because development
can execute jobs in-process.

Action Mailer owns message composition/delivery. Production SMTP configuration
and the `latency_10s` `deliver_later` queue live in
[`production.rb`](config/environments/production.rb). Some jobs intentionally
call `deliver_now` *inside an already-queued job*; preserve that boundary unless
changing retry/queue semantics deliberately.

Slack has three boundaries: OAuth/provider identity in the user concerns,
signed command ingress in [`SlackController`](app/controllers/slack_controller.rb),
and queued command/profile/status work. Outside development, commands require a
valid Slack HMAC signature and timestamp within five minutes. Background profile
and notification name lookups use [`Cachet`](lib/cachet.rb), without Slack tokens
or a direct Slack API fallback. A Cachet cache miss (HTTP 202) must not overwrite
stored profile data; the profile job retries before leaving it due for the next
scheduled refresh. Slack OAuth still fetches identity data directly from Slack.
Profile assignment and Slack status API calls live in
[`SlackIntegration`](app/models/concerns/slack_integration.rb); controllers should
authenticate, validate and enqueue.

## 7. Time zones, transactions and concurrency

Heartbeat `time` is Unix epoch time. Calendar concepts (today, week, streak,
activity dates) use the validated `User#timezone`. Browser requests run inside
`Time.use_zone(current_user.timezone)`; services/jobs without that wrapper must
use `Time.use_zone` explicitly. SQL day grouping converts epochs with the user
timezone and falls back to UTC only where the reporting code explicitly guards
invalid legacy data. A timezone change invalidates both old/new activity cache
keys and rollups.

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
| Add a frontend Rails URL | Rails route with `export: true` + generated helper import |
| Add browser/admin/API authorization | Existing auth concern/controller boundary and model capability predicate |
| Change sign-in/provider identity | `SessionsController` plus the relevant user OAuth/provider concern |
| Change project archive/share/user mapping | `ProjectRepoMapping` and its controller/job |
| Change shared repository metadata/API calls | `Repository` + `RepoHost` service + sync job |
| Add slow, scheduled or retryable work | `ApplicationJob` subclass and GoodJob queue/cron config as needed |
| Compose/send mail | Mailer; enqueue from the owning lifecycle/job |
| Handle Slack command/API behavior | Verified ingress controller, Slack concern/client boundary, then job |
| Change a calendar-day report | Explicit user-zone service/query; invalidate timezone-sensitive derived data |
