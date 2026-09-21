#!/usr/bin/env bash
# Weekly physical base backup. With the continuously archived WAL (archive_command -> ${BACKUP_DIR}/postgres/wal)
# this gives POINT-IN-TIME RECOVERY (RPO <= ~5 min).
JOB=pg_basebackup
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BASE="$BACKUP_DIR/postgres/base"; WAL="$BACKUP_DIR/postgres/wal"
mkdir -p "$BASE" "$WAL"
target="$BASE/base-$(date -u +%Y%m%d-%H%M%S)"
mkdir -p "$target.partial"
log "taking base backup"
pg_basebackup --pgdata="$target.partial" --format=tar --gzip --checkpoint=fast --wal-method=none --no-password \
  || { rm -rf "$target.partial"; die "pg_basebackup failed"; }
mv "$target.partial" "$target"
size="$(du -sb "$target" | cut -f1)"
prune "$BASE" "base-*" "$RETENTION_BASE"
# WAL older than the oldest kept base backup is useless: keep (RETENTION_BASE weeks + 1 day)
find "$WAL" -type f -mtime +"$((RETENTION_BASE * 7 + 1))" -print -delete | sed 's/^/retention: removed wal /' || true
write_status ok "$size"
log "done ($size bytes)"
