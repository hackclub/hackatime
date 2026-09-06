# Heartbeat remapping

Heartbeat remap rules correct deterministic client mistakes during ingestion. A historical run applies the same rules to existing rows. Deploy and apply `20260905203922_create_heartbeat_remapping_tables.rb` before starting web or worker processes that contain the remapping code.

Missing languages and the JetBrains `AUTO_DETECTED` sentinel are inferred only when the language catalogue has one possible owner for the filename or extension. Ambiguous extensions such as `.rs` remain unknown rather than depending on catalogue order. Curated authoritative filenames and extensions correct deterministic client mistakes even when the client supplied a different language.

## Start a run

Create and enqueue a dry run from a Rails console:

```ruby
run = HeartbeatRemapRunner.start!(dry_run: true, batch_size: 1_000)
HeartbeatRemapJob.perform_later(run.id)
```

Review that run, then create a separate write run. A dry run cannot be promoted: each run captures its own `max_heartbeat_id`, so dry and write runs are separate snapshots.

```ruby
run = HeartbeatRemapRunner.start!(dry_run: false, batch_size: 1_000)
HeartbeatRemapJob.perform_later(run.id)
```

Rails 8.1 continuations are enabled because GoodJob 4.19 supports the required stopping hook. The database run, changes and counters remain authoritative for resume, audit and rollback.

## Inspect progress

```ruby
run.reload.slice(
  "id", "state", "dry_run", "cursor_id", "max_heartbeat_id",
  "scanned_count", "changed_count", "deduplicated_count",
  "stale_count", "unsafe_count", "error_count", "error_message"
)
run.remap_changes.group(:action).count
run.remap_changes.order(:id).limit(20).pluck(:heartbeat_id, :action, :preimage, :postimage)
run.remap_alias_changes.order(:id).limit(20).pluck(
  :alias_hash, :before_heartbeat_id, :before_canonical_hash,
  :after_heartbeat_id, :after_canonical_hash
)
```

Runs checkpoint after every committed batch. Re-enqueue the same run ID after an interrupted job.

## Roll back a write run

Only completed write runs can be rolled back:

```ruby
HeartbeatRemapRunner.start_rollback!(run)
HeartbeatRemapJob.perform_later(run.id)
```

Rollback first restores hash-changing winners, then collision losers, so every batch is safe even with `batch_size: 1`. It restores pre-existing aliases and removes aliases created by the run when their current state still matches the audit postimage. Concurrently changed heartbeats or aliases are recorded as stale and left unchanged.

## Scan performance

Candidate selection intentionally scans every heartbeat ID from `cursor_id + 1` through the run's captured `max_heartbeat_id` once. It is an indexed primary-key keyset scan with bounded memory and a constant number of database statements per batch. Rules run linearly in memory and reject overselected rows. This is acceptable for infrequent historical corrections and avoids maintaining rule-specific SQL. Add narrower candidate selection only if production measurement shows the full scan is not viable.
