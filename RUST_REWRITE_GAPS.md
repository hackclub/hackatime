# Rust rewrite gaps

This document records everything that still prevents the Rust API and SvelteKit application from replacing Rails.

The current implementation is a heartbeat ingestion and analytics experiment. It is not a complete Hackatime product implementation.

## Current scope

Measured on 2026-07-28:

- Rust contains 3,061 lines of code across 9 files
- Rails contains 11,491 lines of application Ruby across 197 files
- Rails exposes 199 first-party routes across 60 first-party controllers
- Rails has 70 first-party API routes and 129 first-party non-API routes
- Rust registers 29 routes and documents 28 operations
- 27 documented Rust operations overlap Rails
- Rust adds one bulk heartbeat route
- SvelteKit provides a dashboard, a profile page and a setup page
- Rust has no PostgreSQL insert, update or delete operations
- Rust has six unit tests

The conformance harness covers the selected public analytics scenarios. Passing it does not establish complete Rails parity.

## Existing Rust hotspots

### API module

`apps/api/src/api.rs` contains half of all Rust code. It owns most handlers, PostgreSQL reads, authorization checks and response construction.

Before expanding the API:

- [ ] split handlers by API area
- [ ] replace untyped `serde_json::Value` responses with response structs
- [ ] move shared authorization rules into a focused policy module
- [ ] move relational queries into focused modules without adding generic repository abstractions
- [ ] add integration tests around every mutation and authorization boundary

### Heartbeat module

`apps/api/src/heartbeat.rs` contains a quarter of all Rust code. It owns ingestion, normalization, identity generation and analytics.

Before relying on it as the only heartbeat implementation:

- [ ] test duplicate ingestion under concurrent requests
- [ ] test correction rows and deletes under concurrent merges
- [ ] test account deletion against ClickHouse
- [ ] test account merging against ClickHouse
- [ ] test all filters in combination
- [ ] test fractional timestamps and second-resolution timestamps
- [ ] test daylight saving transitions in every supported query
- [ ] benchmark all `FINAL` queries against production-scale data
- [ ] define retention and partition maintenance
- [ ] define backup and restore procedures

### Query hotspots

- [ ] remove the project mapping N+1 query in `currently_hacking`
- [ ] measure the eleven ClickHouse `FINAL` queries independently
- [ ] bound large heartbeat list responses
- [ ] add request cancellation and query timeouts
- [ ] add database pool saturation metrics
- [ ] add slow query logging
- [ ] add cache hit and miss metrics

## Partial endpoint semantics

These endpoints exist but are not complete replacements.

### User stats

- [ ] calculate the real streak instead of returning zero
- [ ] verify every supported `features` value
- [ ] verify editor, machine, operating system, category, branch and entity grouping
- [ ] verify AI coding exclusion in grouped results
- [ ] match Rails privacy and trust behavior
- [ ] match Rails error bodies for every invalid filter

### Summary

The Rust response currently leaves editors, operating systems, machines, categories, branches, entities and labels empty.

- [ ] implement every summary grouping
- [ ] match interval boundary behavior
- [ ] match explicit start and end boundary behavior
- [ ] include all compatibility aliases
- [ ] define cache invalidation after heartbeat ingestion
- [ ] define cache invalidation after heartbeat correction or deletion

### Last seven days

The Rust response currently represents all nonzero activity as coding.

- [ ] calculate real categories
- [ ] calculate AI coding separately
- [ ] verify the definition of days including holidays
- [ ] verify daily average behavior on empty days
- [ ] verify user timezone behavior around daylight saving transitions
- [ ] match all Rails response fields

### Status bar

- [ ] compare the full response schema against Rails
- [ ] support every user selector allowed by the compatibility API
- [ ] verify timezone boundaries
- [ ] verify visibility rules

### Leaderboards

Rust reads precomputed PostgreSQL leaderboard rows that Rails workers currently generate.

- [ ] implement daily leaderboard generation
- [ ] implement weekly leaderboard generation
- [ ] implement timezone-specific leaderboards if retained
- [ ] implement leaderboard cache invalidation
- [ ] implement shadowban filtering and expiration
- [ ] implement cleanup of old leaderboards
- [ ] implement generation status and failure recovery
- [ ] stop depending on Rails-generated leaderboard rows

### Authentication

Rust authenticates existing API keys from PostgreSQL.

- [ ] support the intended OAuth bearer token behavior
- [ ] support key revocation
- [ ] support key rotation
- [ ] support admin API keys
- [ ] implement constant-time credential comparison where applicable
- [ ] add authentication rate limits
- [ ] add credential audit logging

## Missing API operations

### External and internal APIs

- [ ] `POST /api/internal/revoke`
- [ ] `POST /api/v1/external/slack/oauth`

### Admin access and permissions

- [ ] `GET /api/admin/v1/check`
- [ ] `GET /api/admin/v1/permissions`
- [ ] `PATCH /api/admin/v1/permissions/:id`
- [ ] implement viewer, admin, superadmin and ultraadmin authorization

### Admin API keys

- [ ] `GET /api/admin/v1/admin_api_keys`
- [ ] `GET /api/admin/v1/admin_api_keys/:id`
- [ ] `POST /api/admin/v1/admin_api_keys`
- [ ] `DELETE /api/admin/v1/admin_api_keys/:id`

### Admin user investigation

- [ ] `GET /api/admin/v1/user/info`
- [ ] `GET /api/admin/v1/user/info_batch`
- [ ] `GET /api/admin/v1/user/heartbeats`
- [ ] `GET /api/admin/v1/user/heartbeat_values`
- [ ] `GET /api/admin/v1/user/get_users_by_ip`
- [ ] `GET /api/admin/v1/user/get_users_by_machine`
- [ ] `GET /api/admin/v1/user/stats`
- [ ] `GET /api/admin/v1/user/projects`
- [ ] `GET /api/admin/v1/user/trust_logs`
- [ ] `POST /api/admin/v1/user/get_user_by_email`
- [ ] `POST /api/admin/v1/user/search_fuzzy`
- [ ] `POST /api/admin/v1/user/convict`
- [ ] `GET /api/admin/v1/users/active`
- [ ] `GET /api/admin/v1/users/:id/visualization/quantized`

### Admin heartbeat investigation

- [ ] `GET /api/admin/v1/heartbeats/by_user_agent_segment`
- [ ] `GET /api/admin/v1/heartbeats/ip_machine_pairs`
- [ ] `GET /api/admin/v1/heartbeats/shared_machines`
- [ ] `GET /api/admin/v1/alts/candidates`
- [ ] `GET /api/admin/v1/alts/shared_machines`

### Admin moderation

- [ ] `GET /api/admin/v1/banned_users`
- [ ] `POST /api/admin/v1/audit_logs/counts`
- [ ] `GET /api/admin/v1/trust_level_audit_logs`
- [ ] `GET /api/admin/v1/trust_level_audit_logs/:id`

### Leaderboard shadowbans

- [ ] `GET /api/admin/v1/leaderboard_shadowbans`
- [ ] `GET /api/admin/v1/leaderboard_shadowbans/search_users`
- [ ] `POST /api/admin/v1/leaderboard_shadowbans`
- [ ] `DELETE /api/admin/v1/leaderboard_shadowbans/:user_id`

### Deletion requests

- [ ] `GET /api/admin/v1/deletion_requests`
- [ ] `GET /api/admin/v1/deletion_requests/:id`
- [ ] `POST /api/admin/v1/deletion_requests/:id/approve`
- [ ] `POST /api/admin/v1/deletion_requests/:id/reject`

### Admin timeline

- [ ] `GET /api/admin/v1/timeline`
- [ ] `GET /api/admin/v1/timeline/search_users`
- [ ] `GET /api/admin/v1/timeline/leaderboard_users`

### Documentation

- [ ] provide admin OpenAPI documentation
- [ ] ensure the public OpenAPI document includes the `/api/v1/leaderboard` alias
- [ ] document authentication and error schemas for every operation

## Missing authentication and account lifecycle

### Sessions and sign-in

- [ ] HCA sign-in
- [ ] Slack sign-in and callback
- [ ] GitHub sign-in and callback
- [ ] GitHub unlink
- [ ] email sign-in
- [ ] email verification
- [ ] email resend
- [ ] email linking and unlinking
- [ ] sign-in tokens
- [ ] session cookies
- [ ] sign-out
- [ ] close-window callback flow
- [ ] impersonation and stop impersonating
- [ ] session expiration
- [ ] CSRF protection for browser mutations

### OAuth provider

- [ ] authorization endpoint
- [ ] native authorization endpoint
- [ ] token endpoint
- [ ] token introspection
- [ ] token revocation
- [ ] authorized application management
- [ ] OAuth application creation
- [ ] OAuth application editing
- [ ] OAuth application deletion
- [ ] client secret rotation
- [ ] verified application controls
- [ ] scopes and consent

### User onboarding

- [ ] create users from supported identity providers
- [ ] provision API keys
- [ ] setup flow
- [ ] connect editors
- [ ] create default preferences
- [ ] handle duplicate identities
- [ ] handle identity linking conflicts

## Missing user settings

### Profile

- [ ] display name updates
- [ ] username updates
- [ ] region updates
- [ ] avatar behavior
- [ ] username uniqueness validation

### Appearance

- [ ] theme selection
- [ ] default theme behavior

### Editors

- [ ] editor configuration
- [ ] editor preference persistence

### Privacy

- [ ] public stats visibility
- [ ] coding activity visibility
- [ ] other activity visibility
- [ ] profile visibility
- [ ] project sharing
- [ ] API key rotation

### Notifications

- [ ] email notification preferences
- [ ] Slack notification preferences
- [ ] weekly summary preferences

### Goals

- [ ] goal creation
- [ ] goal update
- [ ] goal deletion
- [ ] goal progress calculation
- [ ] goal progress display

### Integrations

- [ ] Slack connection settings
- [ ] GitHub connection settings
- [ ] repository access settings
- [ ] integration error reporting

## Missing project functionality

- [ ] project list page
- [ ] project detail page
- [ ] public project page
- [ ] project file list
- [ ] project statistics
- [ ] repository mapping creation
- [ ] repository mapping editing
- [ ] repository mapping archive
- [ ] repository mapping restore
- [ ] repository mapping sharing
- [ ] automatic repository matching
- [ ] project alias resolution
- [ ] repository metadata synchronization
- [ ] commit history synchronization

## Missing heartbeat data lifecycle

### Imports

- [ ] WakaTime import upload
- [ ] WakaTime remote download
- [ ] import dump creation
- [ ] import progress
- [ ] import validation
- [ ] retry and recovery
- [ ] duplicate handling
- [ ] import cleanup

### Exports

- [ ] heartbeat export request
- [ ] asynchronous export generation
- [ ] export download
- [ ] export expiration
- [ ] export cleanup

### Corrections and deletion

- [ ] delete individual heartbeats
- [ ] delete a user's heartbeats
- [ ] merge heartbeats between users
- [ ] preserve ReplacingMergeTree correctness during corrections
- [ ] verify `FINAL` behavior after corrections
- [ ] support privacy deletion deadlines
- [ ] prove that deleted data is removed from backups according to policy

## Missing administrative product surfaces

- [ ] admin user list
- [ ] trust level editing
- [ ] account merger
- [ ] deletion request review
- [ ] OAuth application review
- [ ] leaderboard shadowban management
- [ ] admin API key management
- [ ] trust level audit log viewer
- [ ] admin timeline
- [ ] alternate-account investigation
- [ ] heartbeat investigation
- [ ] GoodJob dashboard or a replacement
- [ ] feature flag dashboard or a replacement

## Missing public product surfaces

- [ ] production home page parity
- [ ] sign-in page
- [ ] full signed-in dashboard
- [ ] activity graph
- [ ] project timeline
- [ ] languages chart
- [ ] editors chart
- [ ] operating systems chart
- [ ] machines chart
- [ ] categories chart
- [ ] branches and entities views
- [ ] streak display
- [ ] goals display
- [ ] leaderboard pages
- [ ] public profile parity
- [ ] public project pages
- [ ] profile Open Graph images
- [ ] extension directory
- [ ] API key page
- [ ] documentation pages
- [ ] settings pages
- [ ] deletion flow
- [ ] OAuth application pages
- [ ] OAuth consent pages
- [ ] error pages
- [ ] sitemap
- [ ] static marketing routes

## Missing background processing

Rails currently defines 47 jobs. Each job needs a Rust worker implementation, a replacement design or an explicit product decision to remove it.

### Cache and rollup jobs

- [ ] active projects cache
- [ ] active users graph cache
- [ ] activity cache
- [ ] currently hacking cache
- [ ] currently hacking count cache
- [ ] heartbeat count cache
- [ ] home statistics cache
- [ ] minutes logged cache
- [ ] dashboard rollup refresh

### Leaderboard jobs

- [ ] leaderboard update
- [ ] old leaderboard cleanup
- [ ] shadowban expiration

### Import and export jobs

- [ ] heartbeat import
- [ ] heartbeat import dump
- [ ] remote heartbeat import download
- [ ] heartbeat export
- [ ] heartbeat export cleanup

### Account jobs

- [ ] account deletion processing
- [ ] expired email verification cleanup
- [ ] email sign-in handling
- [ ] geocode users without a country
- [ ] Slack username updates

### Repository and GitHub jobs

- [ ] attempt project repository mapping
- [ ] pull repository commits
- [ ] process commits
- [ ] scan GitHub repositories
- [ ] scan repository events for commits
- [ ] synchronize repository metadata
- [ ] synchronize stale repository metadata
- [ ] synchronize user repository events
- [ ] synchronize all user repository events

### Slack and Sailors Log jobs

- [ ] Sailors Log notifications
- [ ] Sailors Log polling
- [ ] Sailors Log help command
- [ ] Sailors Log command
- [ ] Sailors Log leaderboard command
- [ ] Sailors Log on and off command
- [ ] Slack channel cache updates
- [ ] user Slack status updates

### Email jobs

- [ ] onboarding check-in email
- [ ] weekly summary email
- [ ] weekly per-user summary email

### Maintenance jobs

- [ ] successful job cleanup
- [ ] GeoLite2 database updates

The replacement worker system also needs:

- [ ] durable queues
- [ ] retry policies
- [ ] dead letter handling
- [ ] concurrency controls
- [ ] priority queues
- [ ] idempotency
- [ ] scheduled execution
- [ ] job metrics
- [ ] job administration
- [ ] graceful worker shutdown

## Missing services

The following Rails service behavior needs to be ported or deliberately removed:

- [ ] user anonymization
- [ ] dashboard snapshots
- [ ] dashboard rollup refresh
- [ ] dashboard statistics
- [ ] HCA integration
- [ ] heartbeat import dump client
- [ ] heartbeat import runner
- [ ] heartbeat import service
- [ ] heartbeat ingestion parity
- [ ] leaderboard cache
- [ ] leaderboard date ranges
- [ ] leaderboard page cache
- [ ] leaderboard calculation
- [ ] profile Open Graph image generation
- [ ] profile statistics
- [ ] programming goal progress
- [ ] project statistics query
- [ ] project statistics
- [ ] GitHub repository host integration
- [ ] repository host factory
- [ ] timeline generation
- [ ] WakaTime user agent parsing parity

## Missing email and storage systems

- [ ] transactional email delivery
- [ ] email templates
- [ ] email previews for development
- [ ] inbound email behavior if retained
- [ ] object storage configuration
- [ ] direct uploads if retained
- [ ] file download authorization
- [ ] image variants
- [ ] cleanup of expired objects

## Missing Slack functionality

- [ ] Slack OAuth user creation
- [ ] Slack sign-in
- [ ] Slack account linking
- [ ] Slack commands
- [ ] Slack status updates
- [ ] Slack channel lookup
- [ ] notification preferences
- [ ] Sailors Log integration
- [ ] request signature verification
- [ ] retry and rate limit handling

## Missing GitHub functionality

- [ ] GitHub sign-in
- [ ] GitHub account linking
- [ ] GitHub account unlinking
- [ ] repository discovery
- [ ] repository event synchronization
- [ ] commit ingestion
- [ ] repository metadata
- [ ] API rate limit handling
- [ ] installation and token lifecycle

## Missing moderation and compliance

- [ ] trust level changes
- [ ] trust audit logs
- [ ] alternate-account detection
- [ ] shared IP investigation
- [ ] shared machine investigation
- [ ] user conviction workflow
- [ ] leaderboard shadowbans
- [ ] deletion request approval
- [ ] deletion request rejection
- [ ] account anonymization
- [ ] account merging
- [ ] admin impersonation
- [ ] permission audit

## Missing operational infrastructure

### Database management

- [ ] make the Rust application own PostgreSQL migrations
- [ ] establish migration rollback policy
- [ ] test clean database bootstrap
- [ ] test upgrades from every supported release
- [ ] define ClickHouse schema migration ordering
- [ ] define ClickHouse cluster migration behavior
- [ ] validate account merges without Rails

### Production runtime

- [ ] Rust worker process
- [ ] scheduler process
- [ ] production SvelteKit deployment configuration
- [ ] health checks for every dependency
- [ ] readiness checks
- [ ] graceful shutdown testing
- [ ] structured request IDs
- [ ] distributed tracing
- [ ] error reporting
- [ ] metrics and dashboards
- [ ] alerts
- [ ] rate limiting
- [ ] abuse protection
- [ ] secret management
- [ ] backup and restore
- [ ] disaster recovery

### Caching

- [ ] replace Solid Cache behavior where still required
- [ ] define cache ownership
- [ ] define invalidation for all user mutations
- [ ] define invalidation for heartbeat ingestion
- [ ] define invalidation for account merges
- [ ] define multi-instance cache behavior

## Missing test coverage

### Rust tests

- [ ] handler tests for every endpoint
- [ ] authorization tests for every endpoint
- [ ] PostgreSQL integration tests
- [ ] ClickHouse integration tests
- [ ] mutation rollback tests
- [ ] queue and worker tests
- [ ] retry and idempotency tests
- [ ] account merge tests
- [ ] deletion tests
- [ ] OAuth tests
- [ ] session tests
- [ ] email tests
- [ ] Slack signature tests
- [ ] GitHub integration tests

### Conformance harness

- [ ] cover every first-party Rails API route
- [ ] compare mutation side effects
- [ ] compare database state after each mutation
- [ ] compare authorization failures
- [ ] compare admin permission levels
- [ ] compare pagination
- [ ] compare sorting
- [ ] compare malformed input
- [ ] compare empty datasets
- [ ] compare large datasets
- [ ] compare duplicate heartbeats
- [ ] compare corrected heartbeats
- [ ] compare deleted heartbeats
- [ ] compare merged accounts
- [ ] compare all timezone boundaries
- [ ] compare all filter combinations
- [ ] compare response headers and redirects

### SvelteKit tests

- [ ] component tests
- [ ] page load tests
- [ ] form validation tests
- [ ] authentication browser tests
- [ ] settings browser tests
- [ ] admin browser tests
- [ ] import and export browser tests
- [ ] accessibility tests
- [ ] visual regression tests

## Rails deletion criteria

Rails can be removed only after all of the following are true:

- [ ] every retained first-party route has a Rust or SvelteKit replacement
- [ ] every retained background job has a replacement
- [ ] every retained service has a replacement
- [ ] all required PostgreSQL mutations are implemented
- [ ] all ClickHouse corrections, merges and deletions are implemented
- [ ] production users can sign in without Rails
- [ ] new users can complete onboarding without Rails
- [ ] OAuth clients continue to work without Rails
- [ ] leaderboards stay current without Rails workers
- [ ] imports and exports work without Rails workers
- [ ] Slack and GitHub integrations work without Rails
- [ ] email delivery works without Rails
- [ ] admin and moderation workflows work without Rails
- [ ] account deletion and anonymization work without Rails
- [ ] SvelteKit contains every retained product surface
- [ ] full API conformance passes
- [ ] mutation side-effect conformance passes
- [ ] production-scale benchmarks meet agreed targets
- [ ] observability and incident response are ready
- [ ] backup and restore drills pass
- [ ] a production shadow run finds no unexplained differences
- [ ] a rollback plan has been tested

Until these criteria are satisfied, Rails remains a production dependency even if core heartbeat ingestion is served by Rust.
