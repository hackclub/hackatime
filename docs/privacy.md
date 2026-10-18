# Privacy requests

Hack Club's [data yeeter](https://yeet.hackclub.com/docs/deletions) calls these
endpoints directly on the Hackatime API server:

| Endpoint | Behaviour |
| --- | --- |
| `POST /api/privacy/delete` | Permanently erases the subject, or executes the same database erasure and rolls it back for a dry run |
| `POST /api/privacy/export` | Reports counts of the data held, without modifying subject data, even when `dry_run` is false |

There is no request body. Neither endpoint reads account identifiers or
`dry_run` from query parameters, cookies or the request body. They do not use
ordinary API keys, OAuth access tokens or browser authentication.

## Authentication and responses

Send `Authorization: Bearer <token>`, where the token is an ES256 JWT signed by
Yeeter. `Privacy::Token` uses the `jwt` gem and verifies:

- `alg: ES256`, `typ: JWT`, the signature and the key named by `kid`
- issuer `hackclub-privacy` and the exact audience string **`hackatime`**
- required, correctly typed claims, expiry and issue time with 30 seconds of leeway
- a lifetime (`exp - iat`) of at most 300 seconds
- an `action` matching the endpoint

Public keys come from
`https://yeet.hackclub.com/.well-known/jwks.json`. They are cached in process for
five minutes. An unknown `kid` triggers a refresh at most once every 30 seconds.
For a local Yeeter, override the URL with `PRIVACY_JWKS_URL`. No audience
configuration is needed in production.

Each verified `jti` is inserted into `privacy_token_uses`, whose primary key
prevents concurrent replays. Receipts older than a day are pruned. **The replay
receipt is the sole intentional persistent write for exports and dry runs.**
It contains only the `jti` and use time, not the subject or token. A failed
operation also consumes its token; a retry must carry a fresh `jti`.

Successful responses contain exactly:

```json
{
  "request_id": "the-request-id-from-the-token",
  "found": true,
  "dry_run": true,
  "deleted": { "users": 1, "heartbeats": 42 },
  "retained": [
    {
      "type": "trust_level_audit_logs",
      "count": 2,
      "reason": "decisions about other users; actor references and free-text copies removed"
    }
  ]
}
```

The `request_id` and `dry_run` are echoed unchanged. Counts contain no personal
data. Zero-count types are omitted. Export returns `deleted: {}` and lists held
record counts in `retained`; it does not generate or email a data archive.
If no account or directly attributable leftover record matches, `found` is false.

Errors contain only `{"error":"snake_case_code"}`:

| Status | Code | Meaning |
| --- | --- | --- |
| 401 | `invalid_token` | Invalid signature, headers, claims, audience or time window |
| 400 | `action_mismatch` | A valid token was sent to the wrong endpoint |
| 409 | `replayed` | The token has already been consumed |
| 409 | `manual_review_required` | Shared integration ownership, shared attachments or mixed-owner job batches require a human decision |
| 503 | `jwks_unavailable` | Public keys could not be fetched or parsed |
| 503 | `storage_unavailable` | Object storage, local file removal or cache clearing failed |
| 503 | `work_in_progress` | Relevant jobs are running or database locks/queries timed out; retry with a fresh token |
| 500 | `internal_error` | An unexpected failure; no exception details or identifiers are returned |

## Finding the subject

All matching accounts are included, not just the first match:

- `subject.emails` is compared case-insensitively with **all** `email_addresses`,
  including secondary and preserved-for-deletion addresses.
- `subject.slack_id` matches `users.slack_uid`.
- `subject.identity_id` matches `users.hca_id`, which holds the HCA `ident!…` ID.

Absent Slack/HCA IDs never match null database values. All addresses and Slack
IDs on matched accounts are also used to find local historical copies. Matching
email-verification, Sailor's Log and history rows can be removed even when the
account itself is already absent. Unattributable anonymous visitor feedback
cannot be matched to these subject claims.

## What is deleted

`Privacy::Eraser` follows the explicit credential/import cleanup in the existing
`AnonymizeUserService`, but physically deletes personal records instead of
preserving email addresses and soft-deleting activity. The existing self-service
deletion process is unchanged.

| Tables | Deleted data |
| --- | --- |
| `users` | Account, profile, provider identities/tokens, preferences and permissions |
| `email_addresses`, `email_verification_requests`, `sign_in_tokens` | Every login/secondary address, verification request and sign-in/OAuth return payload |
| `api_keys`, `admin_api_keys`, `oauth_access_grants`, `oauth_access_tokens` | Personal API credentials, revoked admin keys and delegated access |
| `heartbeats`, `heartbeat_exclusions` | All activity, including excluded and soft-deleted rows, IPs, file paths and rules about the subject |
| `dashboard_rollups`, `goals`, `project_labels`, `project_repo_mappings` | Derived activity, goals, labels and personal project/repository settings |
| `heartbeat_import_runs`, `heartbeat_import_sources`, `instance_import_sources`, `wakatime_mirrors` | Current and legacy import/mirror credentials, progress, errors and configuration |
| `commits`, `repo_host_events` | Imported commits owned by the subject and their raw repository event copies |
| `leaderboard_entries` | The subject's entries; remaining display ranks derive from remaining participants |
| `sailors_logs`, `sailors_log_notification_preferences`, `sailors_log_slack_notifications` | Slack-ID-linked summaries, preferences and pending/sent notification records |
| `sailors_log_leaderboards` | Generated messages requested by or mentioning the subject |
| `deletion_requests`, `trust_level_audit_logs` | Requests and moderation history about the subject |
| `documentation_feedbacks`, `mailkick_subscriptions`, `flipper_gates` | Account-linked feedback, mailing preferences and user-specific feature gates |
| `versions` | PaperTrail copies of erased records, history attributed to the subject and history containing known email/Slack/HCA identifiers. Historical copies of records detached during erasure are removed too |
| `good_jobs`, `good_job_executions`, `good_job_batches` | Attributable queued/completed work, serialized arguments, execution errors and exclusively attributable batches |
| `notable_requests`, `notable_jobs`, `pghero_query_stats` | Attributable request/job history and stored query samples containing known identifiers |
| `active_storage_attachments`, `active_storage_blobs`, `active_storage_variant_records` | Profile OG images, tracked variants and unattached heartbeat export ZIPs marked with the subject's user ID |
| `repositories` | Repository metadata that becomes unreferenced by any mapping or commit |
| `solid_cache_entries` | The legacy primary-database cache is cleared in the transaction. The active application cache is also cleared before commit |

Direct SQL/bulk deletions intentionally avoid callbacks that would enqueue mail,
new history or replacement data. Session cookies cease to identify an account
once its user row is gone.

### Files and caches

- Active Storage deletes files from their configured service (production R2/S3,
  development `storage/`, test `tmp/storage/`) and variant prefixes. Unattached
  export blobs are found by `heartbeat_export` and `user_id` metadata.
- Import files and context sidecars under `tmp/heartbeat_imports/` are found from
  the subject's import-run IDs and removed.
- A real deletion clears the whole application cache, including shared
  leaderboard/activity payloads, avatar bytes, email lookups and per-user keys.
  This is deliberate: invalidating a cache key does not physically erase its
  previous value. Other users may briefly experience cold caches. Dry runs and
  exports do not clear caches.

## What is kept, detached

Each matching retained kind is reported with a count and reason:

| Kept | Why and how it is detached |
| --- | --- |
| Shared `repositories` | Public metadata other users' mappings/commits need; the subject's mappings and commits are removed |
| Other users' `commits` containing the subject's author/committer email or GitHub ID | Preserve their imported commit record, removing copied author/committer identity from the JSON payload |
| Shared `leaderboards` | Other participants' standings remain. Personal entries and cached payloads are removed |
| Other users' `trust_level_audit_logs` | Keep moderation decisions, null subject actor/editor references and clear free-text/current/original notes and reasons that could identify the author |
| Other users' `deletion_requests` | Keep their workflow, null the subject's approval reference |
| Other users' `heartbeat_exclusions` | Keep their visibility rules, null subject creator/revoker references |
| Other users' `users` | Keep accounts and moderation state, null the subject's shadowbanning-administrator reference |

Shared infrastructure is not user-owned: `flipper_features`, `good_job_processes`,
`good_job_settings`, `ja4s` and `pghero_space_stats` remain. Shared feature gates,
anonymous documentation feedback and unrelated query/job history remain too.

### Work requiring a human

Deletion and dry-run deletion return `409 manual_review_required` rather than
guessing when the subject owns an OAuth application, holds an active admin API
key, shares a blob with another record or participates in a mixed-owner job
batch. Staff must transfer integration ownership, revoke/reissue credentials or
resolve the shared record before submitting a new request. Export can still
report holdings.

Matched users are locked, and deletion briefly locks the job table against new
enqueues/claims. Running subject jobs or global writers that could recreate
data produce `503 work_in_progress`. This closes outstanding local work without
sending more email or Slack notifications.

## Transactions and retries

Dry runs perform the actual database deletion, use affected-row counts and roll
back. There is no separate deletion estimator. Real runs take the same path and
remove external files and cache copies **before committing**. A storage failure
rolls back the account transaction so a fresh-token retry can still find it.
Some external files may already have been removed before a later operation
fails; deleting missing objects is safe on retry. External deletion itself
cannot be rolled back.

Database locks and individual statements have bounded waits. Large accounts or
busy workers may need operational attention to complete within Yeeter's
15-second request deadline. Concurrent legitimate new activity between review
and execution can also change counts; the dry run is not a frozen snapshot.

## Logging and external boundaries

Privacy requests suppress normal Rails request/SQL logging and Sentry events,
profiles, breadcrumbs and request logs. Skylight excludes both endpoints. The
application records only the verified `request_id` and outcome. It does not log
JWTs, claims, emails, Slack IDs, HCA IDs or deleted content. Configure
ingress/proxy/APM systems not to capture privacy Authorization headers, bodies
or query strings either.

These endpoints do **not** claim to erase independent systems:

| System | Boundary |
| --- | --- |
| Slack | Local copies and pending messages are deleted; already posted messages and remote profile/status copies require workspace-side handling |
| Hack Club Auth | Local IDs/tokens are deleted; remote identity deletion belongs to Yeeter's HCA target |
| GitHub | Local credentials/activity copies are removed; remote accounts, public commits and repositories are not deleted |
| WakaTime and legacy Hackatime | Local import/mirror work is removed; upstream accounts and remote data dumps require their own deletion |
| SMTP/email provider and recipients | Queued local payloads are removed; delivered email and delivery logs follow provider/recipient policy. `LoopsMailer` uses Rails SMTP, not a direct Loops API integration |
| Sentry, Skylight and Plausible | Historical telemetry/analytics requires provider-side retention or erasure; this repository does not provide deletion credentials or a reliable subject index |
| OAuth/API consumers | Revoking local access cannot recall copies another program already downloaded; those programs need their own privacy targets |
| Infrastructure | Backups, WAL/PITR, replicas, bucket version history, CDN/platform logs and snapshots require operator-managed retention/erasure. A restore must not reintroduce erased accounts into service |

Interrupted worker files without ownership metadata, arbitrary mentions in
unstructured text and historical telemetry that cannot be attributed from the
signed subject require operator review. Infrastructure and provider copies are
not included in the endpoint's deletion counts. These boundaries must be
handled by staff alongside the local deletion, not represented as completed
remote erasure.
