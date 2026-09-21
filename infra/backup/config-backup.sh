#!/usr/bin/env bash
# Configuration snapshot: compose, proxy/DB configs, Dockerfiles, migrations, env template. The real .env (secrets) is only
# kept ENCRYPTED with `age` and only when BACKUP_AGE_RECIPIENT (a public key) is set — never in clear text.
JOB=config
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DEST="$BACKUP_DIR/config"; REPO="${REPO_DIR:-/repo}"; mkdir -p "$DEST"
ts="$(date -u +%Y%m%d-%H%M%S)"
tar -C "$REPO" -czf "$DEST/config-$ts.tar.gz" --exclude='.env' --exclude='node_modules' --exclude='.git' --exclude='.dev-data' \
  docker-compose.yml .env.example infra packages/database/prisma 2>/dev/null || die "config archive failed"
size="$(file_size "$DEST/config-$ts.tar.gz")"
if [ -f "$REPO/.env" ]; then
  if [ -n "${BACKUP_AGE_RECIPIENT:-}" ]; then age -r "$BACKUP_AGE_RECIPIENT" -o "$DEST/env-$ts.age" "$REPO/.env" && log "encrypted .env saved"
  else log "WARNING: BACKUP_AGE_RECIPIENT not set — .env (secrets) is NOT in the backup. Keep it in your password manager!"; fi
fi
prune "$DEST" "config-*.tar.gz" "$RETENTION_DAILY"; prune "$DEST" "env-*.age" "$RETENTION_DAILY"
write_status ok "$size"
log "done"
