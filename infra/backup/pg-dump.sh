#!/usr/bin/env bash
# Nightly logical backup (custom format: compressed, selective restore). Rotation: daily N + weekly (Sun) + monthly (1st).
JOB=pg_dump
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DAILY="$BACKUP_DIR/postgres/daily"; WEEKLY="$BACKUP_DIR/postgres/weekly"; MONTHLY="$BACKUP_DIR/postgres/monthly"
mkdir -p "$DAILY" "$WEEKLY" "$MONTHLY"
ts="$(date -u +%Y%m%d-%H%M%S)"
tmp="$DAILY/.${PGDATABASE}-${ts}.dump.partial"
out="$DAILY/${PGDATABASE}-${ts}.dump"

log "dumping ${PGDATABASE} from ${PGHOST}"
pg_dump --format=custom --compress=6 --no-owner --no-privileges --file="$tmp" || { rm -f "$tmp"; die "pg_dump failed"; }
pg_restore --list "$tmp" > /dev/null || { rm -f "$tmp"; die "dump is not a valid archive"; }
[ "$(file_size "$tmp")" -gt 1024 ] || { rm -f "$tmp"; die "dump is suspiciously small"; }
mv "$tmp" "$out"
( cd "$DAILY" && sha256sum "$(basename "$out")" > "$(basename "$out").sha256" )
size="$(file_size "$out")"
log "created $out ($size bytes)"

[ "$(date -u +%u)" = "7" ] && cp -p "$out" "$out.sha256" "$WEEKLY/" && log "promoted to weekly"
[ "$(date -u +%d)" = "01" ] && cp -p "$out" "$out.sha256" "$MONTHLY/" && log "promoted to monthly"
for d in "$DAILY:$RETENTION_DAILY" "$WEEKLY:$RETENTION_WEEKLY" "$MONTHLY:$RETENTION_MONTHLY"; do
  prune "${d%%:*}" "${PGDATABASE}-*.dump" "${d##*:}"; prune "${d%%:*}" "${PGDATABASE}-*.dump.sha256" "${d##*:}"
done
write_status ok "$size"
log "done"
