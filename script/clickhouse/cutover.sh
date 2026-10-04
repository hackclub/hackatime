#!/bin/bash
# Moves heartbeats from Postgres to ClickHouse. Run on the hackatime box, from a
# checkout of this repo, one step at a time:
#
#   backfill  Copy every heartbeat up to now into ClickHouse, dropping exact
#             duplicates. No downtime; run it shortly before the cutover.
#   pause     Make Postgres heartbeats read-only. The running app's heartbeat
#             writes now fail, and editor clients queue and retry them.
#   delta     Copy what changed since the backfill: new rows, soft deletes
#             from account deletions and nullified JA4 references.
#   (deploy the ClickHouse version of the app; clients' retries land there)
#   verify    Re-copy the frozen Postgres table and check every row against
#             ClickHouse. Safe to run after writes have resumed.
#   repair    If verify found rows whose deleted_at or ja4_id differ, copy
#             Postgres's values over, then verify again.
#   unpause   Abort: make Postgres heartbeats writable again.
#
# Environment:
#   PG_URL        Postgres. backfill and verify may use a read replica; pause,
#                 delta and unpause need the primary.
#   CH            ClickHouse client command, e.g. /root/hackatime-ch-prod/ch
#   DST_DB        Database the app reads            (default: hackatime)
#   STAGING_DB    Database for raw copies           (default: hackatime_staging)
#   STATE_DIR     Watermarks and progress markers   (default: /var/lib/hackatime-cutover)
#   PARALLEL      Concurrent copy streams           (default: 8)
#   MARGIN_IDS    Ids below the backfill watermark the delta re-checks, to catch
#                 rows that committed after the backfill read (default: 2000000)
#
# Production order:
#   1. backfill (about 20 minutes, no downtime), with CH=/root/hackatime-ch-prod/ch
#      and PG_URL the read replica.
#   2. Build the ClickHouse release image, then: pause and delta with PG_URL the
#      primary. Heartbeat writes fail until the deploy is live; editor clients
#      queue them and retry. A heartbeat import running at the pause fails and
#      has to be restarted.
#   3. Deploy. db:prepare runs the migrations and creates ClickHouse's tables.
#   4. bin/rails clickhouse:rollups:rebuild to warm every user's dashboard.
#   5. verify (and repair if needed) against the replica.
set -euo pipefail

STEP=${1:?usage: cutover.sh backfill|pause|delta|verify|repair|unpause}
: "${PG_URL:?set PG_URL}" "${CH:?set CH}"
DST_DB=${DST_DB:-hackatime}
STAGING_DB=${STAGING_DB:-hackatime_staging}
STATE_DIR=${STATE_DIR:-/var/lib/hackatime-cutover}
PARALLEL=${PARALLEL:-8}
MARGIN_IDS=${MARGIN_IDS:-2000000}
CHUNK_IDS=2000000
SHARDS=32
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$STATE_DIR"

log() { echo "$(date -u +%FT%TZ) $*" >&2; }
pg() { psql "$PG_URL" -v ON_ERROR_STOP=1 -XAtq "$@"; }
ch() { $CH --receive_timeout 3600 --max_execution_time 0 "$@"; }
state() { cat "$STATE_DIR/$1"; }

# Columns copied out of Postgres, in the order of the staging table below.
# Dependencies may be a multidimensional legacy array; those keep their text.
PG_COLUMNS="id, user_id, time, project, branch, entity, category, editor, language, machine,
  operating_system, type, user_agent, host(ip_address),
  CASE WHEN array_ndims(dependencies) > 1 THEN dependencies::text ELSE array_to_json(dependencies)::text END,
  CASE WHEN dependencies IS NULL THEN 't' ELSE 'f' END, coalesce(array_ndims(dependencies), 1),
  lineno, lines, cursorpos, line_additions, line_deletions, project_root_count, is_write, source_type,
  ja4_id, ai_model, ai_session, ai_subscription_plan, ai_input_tokens, ai_output_tokens, ai_prompt_length,
  ai_line_changes, human_line_changes, deleted_at, created_at, updated_at"

HEARTBEAT_COLUMNS="id, user_id, time, project, branch, entity, category, editor, language, machine,
  operating_system, type, user_agent, ip_address, dependencies, dependencies_is_null, dependencies_json,
  lineno, lines, cursorpos, line_additions, line_deletions, project_root_count, is_write, source_type,
  ja4_id, ai_model, ai_session, ai_subscription_plan, ai_input_tokens, ai_output_tokens, ai_prompt_length,
  ai_line_changes, human_line_changes, deleted_at, created_at, updated_at"

# Two heartbeats are the same heartbeat when everything but id, timestamps and
# deleted_at matches (see script/clickhouse/backfill_dedup.sql).
IDENTITY="user_id, time, entity, type, project, branch, language, editor, category, machine,
  operating_system, user_agent, lineno, lines, cursorpos, line_additions, line_deletions,
  project_root_count, is_write, dependencies, dependencies_is_null, dependencies_json, ai_model,
  ai_session, ai_subscription_plan, ai_input_tokens, ai_output_tokens, ai_prompt_length,
  ai_line_changes, human_line_changes, source_type, ip_address, ja4_id"

create_staging_table() {
  ch --query "CREATE DATABASE IF NOT EXISTS $STAGING_DB"
  ch --query "CREATE TABLE IF NOT EXISTS $STAGING_DB.$1 AS $DST_DB.heartbeats"
}

# Streams Postgres rows matching a WHERE clause into a staging table.
copy_where() {
  local table=$1 where=$2 columns
  # \copy must be a single line.
  columns=$(tr -s '\n ' ' ' <<< "$PG_COLUMNS")
  pg -c "\copy (SELECT $columns FROM heartbeats WHERE $where) TO STDOUT WITH (FORMAT csv, NULL '\N', FORCE_QUOTE *)" \
    | ch --async_insert=0 --insert_deduplicate=0 --query "
      INSERT INTO $STAGING_DB.$table ($HEARTBEAT_COLUMNS)
      SELECT id, user_id, time, project, branch, entity, category, editor, language, machine,
        operating_system, type, user_agent, ip_address,
        if(deps_null = 't' OR deps_ndims > 1, [], JSONExtract(assumeNotNull(deps), 'Array(String)')),
        deps_null = 't', if(deps_ndims > 1, deps, NULL),
        lineno, lines, cursorpos, line_additions, line_deletions, project_root_count,
        if(is_write IS NULL, NULL, is_write = 't'), source_type, ja4_id, ai_model, ai_session,
        ai_subscription_plan, ai_input_tokens, ai_output_tokens, ai_prompt_length, ai_line_changes,
        human_line_changes, deleted_at, created_at, updated_at
      FROM input('id UInt64, user_id UInt64, time Float64, project Nullable(String), branch Nullable(String),
        entity Nullable(String), category Nullable(String), editor Nullable(String), language Nullable(String),
        machine Nullable(String), operating_system Nullable(String), type Nullable(String),
        user_agent Nullable(String), ip_address Nullable(String), deps Nullable(String), deps_null String,
        deps_ndims UInt8, lineno Nullable(Int32), lines Nullable(Int32), cursorpos Nullable(Int32),
        line_additions Nullable(Int32), line_deletions Nullable(Int32), project_root_count Nullable(Int32),
        is_write Nullable(String), source_type UInt8, ja4_id Nullable(UInt64), ai_model Nullable(String),
        ai_session Nullable(String), ai_subscription_plan Nullable(String), ai_input_tokens Nullable(Int64),
        ai_output_tokens Nullable(Int64), ai_prompt_length Nullable(Int32), ai_line_changes Nullable(Int32),
        human_line_changes Nullable(Int32), deleted_at Nullable(DateTime64(6, \\'UTC\\')),
        created_at DateTime64(6, \\'UTC\\'), updated_at DateTime64(6, \\'UTC\\')')
      FORMAT CSV"
}

# Copies ids [1, upto] into a staging table in parallel chunks. Resumable.
copy_all() {
  local table=$1 upto=$2 done_dir="$STATE_DIR/$1.done"
  mkdir -p "$done_dir"
  export -f copy_where pg ch log
  export PG_URL CH STAGING_DB PG_COLUMNS HEARTBEAT_COLUMNS
  seq 0 "$CHUNK_IDS" "$upto" | xargs -P "$PARALLEL" -I{} bash -c '
    set -euo pipefail
    start={}; end=$((start + '"$CHUNK_IDS"')); [ -f "'"$done_dir"'/$start" ] && exit 0
    copy_where "'"$table"'" "id > $start AND id <= LEAST($end, '"$upto"')"
    touch "'"$done_dir"'/$start"'
}

apply_schema() {
  ch --query "CREATE DATABASE IF NOT EXISTS $DST_DB"
  for file in "$ROOT"/db/clickhouse/*.sql; do
    ch --database "$DST_DB" --multiquery < "$file"
  done
}

read_only_sql() {
  cat <<'SQL'
SET lock_timeout = '10s';
CREATE OR REPLACE FUNCTION heartbeats_read_only() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'heartbeats is read-only: heartbeats are stored in ClickHouse';
END
$$;
DROP TRIGGER IF EXISTS heartbeats_read_only ON heartbeats;
CREATE TRIGGER heartbeats_read_only
  BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE ON heartbeats
  FOR EACH STATEMENT EXECUTE FUNCTION heartbeats_read_only();
SQL
}

case "$STEP" in
backfill)
  apply_schema
  [ "$(ch --query "SELECT count() FROM $DST_DB.heartbeats")" = 0 ] || { log "$DST_DB.heartbeats is not empty"; exit 1; }
  create_staging_table heartbeats_pg
  if [ ! -f "$STATE_DIR/backfill_watermark" ]; then
    pg -c "SELECT now() AT TIME ZONE 'UTC'" > "$STATE_DIR/backfill_started_at"
    pg -c "SELECT coalesce(max(id), 0) FROM heartbeats" > "$STATE_DIR/backfill_watermark"
  fi
  watermark=$(state backfill_watermark)
  log "copying ids up to $watermark"
  copy_all heartbeats_pg "$watermark"
  log "removing exact duplicates into $DST_DB.heartbeats"
  for shard in $(seq 0 $((SHARDS - 1))); do
    ch --param_src_db="$STAGING_DB" --param_src=heartbeats_pg --param_dst_db="$DST_DB" --param_dst=heartbeats \
       --param_shard="$shard" --param_shards="$SHARDS" < "$ROOT/script/clickhouse/backfill_dedup.sql"
  done
  log "backfill done: $(ch --query "SELECT count() FROM $STAGING_DB.heartbeats_pg") copied, $(ch --query "SELECT count() FROM $DST_DB.heartbeats") kept"
  ;;

pause)
  read_only_sql | pg
  pg -c "SELECT coalesce(max(id), 0) FROM heartbeats" > "$STATE_DIR/final_watermark"
  pg -c "SELECT date_trunc('second', now() AT TIME ZONE 'UTC')" > "$STATE_DIR/paused_at"
  if pg -c "INSERT INTO heartbeats SELECT * FROM heartbeats WHERE false" 2>/dev/null; then
    log "Postgres heartbeats still accepts writes"; exit 1
  fi
  log "Postgres heartbeats is read-only; final id $(state final_watermark)"
  ;;

unpause)
  pg -c "DROP TRIGGER IF EXISTS heartbeats_read_only ON heartbeats"
  rm -f "$STATE_DIR/final_watermark" "$STATE_DIR/paused_at"
  log "Postgres heartbeats is writable again"
  ;;

delta)
  [ -f "$STATE_DIR/final_watermark" ] || { log "run pause first"; exit 1; }
  low=$(( $(state backfill_watermark) - MARGIN_IDS )); low=$(( low < 0 ? 0 : low ))
  final=$(state final_watermark)
  create_staging_table heartbeats_delta
  ch --query "TRUNCATE TABLE $STAGING_DB.heartbeats_delta"
  copy_where heartbeats_delta "id > $low AND id <= $final"

  # Bring rows that changed since the backfill up to date first, so new rows
  # are compared against their current state.
  # Account deletions since the backfill soft-delete every heartbeat of the user.
  # They stamp one time on all of the user's live rows, the latest deleted_at.
  pg -F ' ' -c "SELECT user_id, to_char(max(deleted_at), 'YYYY-MM-DD HH24:MI:SS') FROM heartbeats
                WHERE user_id IN (SELECT user_id FROM deletion_requests
                                  WHERE completed_at >= TIMESTAMP '$(state backfill_started_at)' - INTERVAL '1 hour')
                  AND deleted_at IS NOT NULL GROUP BY user_id" \
    | while read -r user_id day time; do
        ch --query "UPDATE $DST_DB.heartbeats SET deleted_at = '$day $time' WHERE user_id = $user_id AND deleted_at IS NULL AND id <= $final"
        log "soft-deleted heartbeats of deleted account $user_id"
      done

  # Deleting a JA4 fingerprint nulls its references (ON DELETE SET NULL).
  ch --query "CREATE TABLE IF NOT EXISTS $STAGING_DB.ja4_ids (id UInt64) ENGINE = MergeTree ORDER BY id"
  ch --query "TRUNCATE TABLE $STAGING_DB.ja4_ids"
  pg -c "\copy (SELECT id FROM ja4s) TO STDOUT" | ch --query "INSERT INTO $STAGING_DB.ja4_ids FORMAT TSV"
  ch --query "UPDATE $DST_DB.heartbeats SET ja4_id = NULL
              WHERE ja4_id IS NOT NULL AND ja4_id NOT IN (SELECT id FROM $STAGING_DB.ja4_ids)"

  # New rows: not already in ClickHouse by id, not an exact duplicate of a row
  # already there (a live copy, or any copy when the new row is deleted), and
  # one survivor per duplicate group within the delta (live first, lowest id).
  before=$(ch --query "SELECT count() FROM $DST_DB.heartbeats")
  ch --query "
    INSERT INTO $DST_DB.heartbeats ($HEARTBEAT_COLUMNS)
    SELECT $HEARTBEAT_COLUMNS FROM (
      SELECT *, row_number() OVER (PARTITION BY $IDENTITY ORDER BY deleted_at IS NOT NULL, id) AS dup_rank
      FROM $STAGING_DB.heartbeats_delta
      WHERE id NOT IN (SELECT id FROM $DST_DB.heartbeats WHERE id > $low)
    )
    WHERE dup_rank = 1
      AND (deleted_at IS NOT NULL OR ($IDENTITY) NOT IN (
        SELECT $IDENTITY FROM $DST_DB.heartbeats
        WHERE (user_id, time) IN (SELECT user_id, time FROM $STAGING_DB.heartbeats_delta) AND deleted_at IS NULL))
      AND (deleted_at IS NULL OR ($IDENTITY) NOT IN (
        SELECT $IDENTITY FROM $DST_DB.heartbeats
        WHERE (user_id, time) IN (SELECT user_id, time FROM $STAGING_DB.heartbeats_delta)))
    SETTINGS transform_null_in = 1, async_insert = 0, insert_deduplicate = 0"
  after=$(ch --query "SELECT count() FROM $DST_DB.heartbeats")
  log "delta: $(ch --query "SELECT count() FROM $STAGING_DB.heartbeats_delta") rows read, $((after - before)) inserted"
  log "delta done"
  ;;

verify)
  [ -f "$STATE_DIR/final_watermark" ] || { log "run pause first"; exit 1; }
  final=$(state final_watermark)
  create_staging_table heartbeats_final
  copy_all heartbeats_final "$final"
  # Rows deleted in ClickHouse after the cutover legitimately differ.
  paused_at=$(state paused_at)
  failed=0
  for shard in $(seq 0 $((SHARDS - 1))); do
    result=$(ch --param_shard="$shard" --param_shards="$SHARDS" --query "
      WITH
        src AS (SELECT id, sipHash64(tuple($HEARTBEAT_COLUMNS)) AS row_hash, sipHash64(tuple($IDENTITY)) AS identity
                FROM $STAGING_DB.heartbeats_final WHERE user_id % {shards:UInt8} = {shard:UInt8}),
        dst AS (SELECT id, sipHash64(tuple($HEARTBEAT_COLUMNS)) AS row_hash
                FROM $DST_DB.heartbeats
                WHERE user_id % {shards:UInt8} = {shard:UInt8} AND id <= $final
                  AND (deleted_at IS NULL OR deleted_at < '$paused_at'))
      SELECT
        (SELECT count() FROM dst LEFT ANTI JOIN src USING (id, row_hash)) AS kept_not_matching_postgres,
        (SELECT uniqExact(identity) FROM src) - (SELECT uniqExact(src.identity) FROM src INNER JOIN $DST_DB.heartbeats AS d USING (id)) AS identities_missing
      FORMAT TSV")
    read -r mismatched missing <<< "$result"
    if [ "$mismatched" != 0 ] || [ "$missing" != 0 ]; then
      failed=1; log "shard $shard: $mismatched rows differ from Postgres, $missing heartbeats missing"
    fi
  done
  [ "$failed" = 0 ] && log "verify passed: every ClickHouse row up to id $final matches Postgres and nothing is missing"
  exit "$failed"
  ;;

repair)
  # After verify: copies deleted_at and ja4_id (the only columns Postgres
  # changes after insert) from the frozen copy onto rows that differ, e.g. a
  # soft delete made from a console that the delta could not see.
  final=$(state final_watermark); paused_at=$(state paused_at)
  ch --query "CREATE TABLE IF NOT EXISTS $STAGING_DB.repairs (id UInt64, deleted_at Nullable(DateTime('UTC')), ja4_id Nullable(UInt64)) ENGINE = MergeTree ORDER BY id"
  ch --query "TRUNCATE TABLE $STAGING_DB.repairs"
  ch --query "
    INSERT INTO $STAGING_DB.repairs
    SELECT src.id, src.deleted_at, src.ja4_id
    FROM $STAGING_DB.heartbeats_final AS src
    INNER JOIN (SELECT id, deleted_at, ja4_id FROM $DST_DB.heartbeats
                WHERE id <= $final AND (deleted_at IS NULL OR deleted_at < '$paused_at')) AS dst USING (id)
    WHERE NOT (src.deleted_at <=> dst.deleted_at AND src.ja4_id <=> dst.ja4_id)"
  ch --format TSV --query "SELECT DISTINCT deleted_at, ja4_id FROM $STAGING_DB.repairs" | while IFS=$'\t' read -r deleted_at ja4_id; do
    [ "$deleted_at" = '\N' ] && deleted_value=NULL || deleted_value="toDateTime('$deleted_at', 'UTC')"
    [ "$ja4_id" = '\N' ] && ja4_value=NULL || ja4_value=$ja4_id
    ch --query "UPDATE $DST_DB.heartbeats SET deleted_at = $deleted_value, ja4_id = $ja4_value
                WHERE id IN (SELECT id FROM $STAGING_DB.repairs WHERE deleted_at <=> $deleted_value AND ja4_id <=> $ja4_value)"
  done
  log "repaired $(ch --query "SELECT count() FROM $STAGING_DB.repairs") rows; run verify again"
  ;;

*)
  echo "unknown step: $STEP" >&2; exit 1
  ;;
esac
