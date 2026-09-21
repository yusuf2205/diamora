#!/usr/bin/env bash
# Restores a logical dump into an EMPTY database (never drops anything):
#   docker compose run --rm backup /opt/backup/restore.sh /backups/postgres/daily/<file>.dump [target-db]
# Point-in-time recovery: docs/DISASTER-RECOVERY.md
JOB=restore
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
dump="${1:-}"; target="${2:-$PGDATABASE}"
[ -f "$dump" ] || { echo "usage: restore.sh <dump-file> [target-db]"; exit 2; }
if [ -f "$dump.sha256" ]; then ( cd "$(dirname "$dump")" && sha256sum -c "$(basename "$dump").sha256" ) || { echo "checksum mismatch — refusing"; exit 1; }; fi
existing="$(psql -d "$target" -qAt -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null || echo err)"
[ "$existing" = "0" ] || { echo "target database '$target' is not empty (tables: $existing). Create an empty one first."; exit 1; }
psql -d "$target" -qAt -c "CREATE EXTENSION IF NOT EXISTS pg_trgm" >/dev/null
pg_restore --dbname="$target" --no-owner --no-privileges --exit-on-error --jobs=2 "$dump"
log "restore finished: $(psql -d "$target" -qAt -c "SELECT count(*) FROM worker_profiles") workers, $(psql -d "$target" -qAt -c "SELECT count(*) FROM audit_logs") audit rows"
