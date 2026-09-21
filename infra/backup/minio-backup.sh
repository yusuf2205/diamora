#!/usr/bin/env bash
# Mirrors every bucket to the NAS backup volume. Deletions are NOT propagated (no --remove): a file deleted by mistake
# (or an attacker) is still present in the backup.
JOB=minio_mirror
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PREFIX="${S3_BUCKET_PREFIX:-}"
BUCKETS="collateral assignments products quality documents avatars"
DEST="$BACKUP_DIR/minio"; mkdir -p "$DEST"
export MC_CONFIG_DIR="${MC_CONFIG_DIR:-/tmp/.mc}"
mc alias set src "$S3_ENDPOINT" "$S3_BACKUP_ACCESS_KEY" "$S3_BACKUP_SECRET_KEY" >/dev/null || die "cannot reach object storage"

failed=0
for b in $BUCKETS; do
  mkdir -p "$DEST/${PREFIX}${b}"
  log "mirroring ${PREFIX}${b}"
  mc mirror --preserve --overwrite --quiet "src/${PREFIX}${b}" "$DEST/${PREFIX}${b}" || { log "ERROR: mirror of ${PREFIX}${b} failed"; failed=1; }
done
[ "$failed" = "0" ] || die "one or more buckets failed to mirror"
size="$(du -sb "$DEST" | cut -f1)"
write_status ok "$size"
log "done ($size bytes on the backup volume)"
