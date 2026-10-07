#!/usr/bin/env bash
# Nightly ClickHouse backup to S3, with a weekly restore check.
#
# Runs on the hackatime box from cron (see script/clickhouse/README.md).
#   - Sunday: full BACKUP of the hackatime database.
#   - Other days: incremental BACKUP on top of the latest full.
#   - Sunday after the full: RESTORE it into a scratch database and compare
#     row counts and a content checksum with the live table.
# S3 credentials live in the server config (see config/clickhouse/config.d), so
# this script only ever passes URLs. Exits non-zero on any failure so cron mail
# and the healthcheck ping catch it.
set -euo pipefail

CONTAINER="${CLICKHOUSE_CONTAINER:-clickhouse-n47qvm3e3raqsdlwo0ife636}"
BASE_URL="${CLICKHOUSE_BACKUP_BASE_URL:-https://hel1.your-objectstorage.com/hackclub-hackatime-backups/clickhouse}"
STATE_DIR="${CLICKHOUSE_BACKUP_STATE_DIR:-/var/lib/hackatime-clickhouse-backup}"
HEALTHCHECK_URL="${CLICKHOUSE_BACKUP_HEALTHCHECK_URL:-}"
TODAY="$(date -u +%F)"
mkdir -p "$STATE_DIR"

ch() {
  docker exec -i "$CONTAINER" bash -c 'clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" --receive_timeout 7200 "$@"' _ "$@"
}

ping_health() {
  [ -n "$HEALTHCHECK_URL" ] && curl -fsS -m 10 --retry 3 "$HEALTHCHECK_URL$1" >/dev/null || true
}
trap 'ping_health /fail' ERR

if [ "$(date -u +%u)" = "7" ] || [ ! -s "$STATE_DIR/latest_full" ]; then
  kind=full
  target="$BASE_URL/full/$TODAY/"
  ch -q "BACKUP DATABASE hackatime TO S3('$target') FORMAT TSV"
  echo "$target" > "$STATE_DIR/latest_full"
else
  kind=incremental
  base="$(cat "$STATE_DIR/latest_full")"
  target="$BASE_URL/incremental/$TODAY/"
  ch -q "BACKUP DATABASE hackatime TO S3('$target') SETTINGS base_backup = S3('$base') FORMAT TSV"
fi
echo "$(date -u +%FT%TZ) $kind backup created: $target"

if [ "$kind" = full ]; then
  # Weekly restore drill: restore into a scratch database and compare with live.
  ch -q "DROP DATABASE IF EXISTS hackatime_restore_check SYNC"
  ch -q "RESTORE DATABASE hackatime AS hackatime_restore_check FROM S3('$target') FORMAT TSV"
  result="$(ch -q "
    SELECT
      (SELECT count() FROM hackatime_restore_check.heartbeats) AS restored,
      (SELECT count() FROM hackatime.heartbeats WHERE created_at <= (SELECT max(created_at) FROM hackatime_restore_check.heartbeats)) AS live,
      (SELECT groupBitXor(cityHash64(id, user_id, time)) FROM hackatime_restore_check.heartbeats) =
      (SELECT groupBitXor(cityHash64(id, user_id, time)) FROM hackatime.heartbeats WHERE id IN (SELECT id FROM hackatime_restore_check.heartbeats)) AS same
    FORMAT TSV")"
  ch -q "DROP DATABASE hackatime_restore_check SYNC"
  read -r restored live same <<< "$result"
  echo "$(date -u +%FT%TZ) restore check: restored=$restored live_at_backup=$live checksum_equal=$same"
  if [ "$same" != "1" ] || [ "$restored" -lt "$live" ]; then
    echo "RESTORE CHECK FAILED" >&2
    exit 1
  fi
fi

ping_health ""
