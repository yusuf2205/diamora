#!/usr/bin/env bash
# Automatic backup verification — a backup nobody restored is only a hope. Restores the newest daily dump into a scratch
# database, checks the data and the money ledger, then drops the scratch database.
JOB=verify
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DAILY="$BACKUP_DIR/postgres/daily"
latest="$(ls -1t "$DAILY"/"${PGDATABASE}"-*.dump 2>/dev/null | head -n1 || true)"
[ -n "$latest" ] || die "no dump found in $DAILY"
( cd "$DAILY" && sha256sum -c "$(basename "$latest").sha256" >/dev/null ) || die "checksum mismatch for $latest"

scratch="verify_$(date -u +%Y%m%d_%H%M%S)"
cleanup() { psql -d postgres -qAt -c "DROP DATABASE IF EXISTS \"$scratch\"" >/dev/null 2>&1 || true; }
trap cleanup EXIT
log "restoring $(basename "$latest") into scratch database $scratch"
psql -d postgres -qAt -c "CREATE DATABASE \"$scratch\"" >/dev/null || die "cannot create scratch database"
psql -d "$scratch" -qAt -c "CREATE EXTENSION IF NOT EXISTS pg_trgm" >/dev/null 2>&1 || true
pg_restore --dbname="$scratch" --no-owner --no-privileges --exit-on-error "$latest" || die "restore into scratch database failed"

count() { psql -d "$1" -qAt -c "SELECT count(*) FROM $2"; }
for table in users worker_profiles worker_collaterals audit_logs worker_ledger_transactions; do
  live="$(count "$PGDATABASE" "$table")"; restored="$(count "$scratch" "$table")"
  log "table $table: live=$live restored=$restored"
  [ "$restored" -le "$live" ] || die "$table: restored has more rows than live — inconsistent"
  if [ "$live" -gt 0 ] && [ "$restored" -eq 0 ]; then die "$table: restored copy is empty"; fi
done
[ "$(count "$scratch" ledger_balance_mismatches)" = "0" ] || die "ledger self-check failed in restored data"
[ "$(count "$scratch" stock_balance_mismatches)" = "0" ] || die "stock self-check failed in restored data"
write_status ok "$(file_size "$latest")"
log "backup verified OK: $(basename "$latest")"
