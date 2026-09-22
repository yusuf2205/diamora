#!/usr/bin/env bash
# Shared helpers for backup jobs (sourced).
set -euo pipefail
# crond does not inherit the container environment: entrypoint.sh persists it here
# shellcheck disable=SC1091
[ -f /tmp/backup-env.sh ] && . /tmp/backup-env.sh

BACKUP_DIR="${BACKUP_DIR:-/backups}"
METRICS_DIR="${METRICS_DIR:-}"
RETENTION_DAILY="${RETENTION_DAILY:-7}"
RETENTION_WEEKLY="${RETENTION_WEEKLY:-4}"
RETENTION_MONTHLY="${RETENTION_MONTHLY:-6}"
RETENTION_BASE="${RETENTION_BASE:-3}"

log() { printf '%s [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${JOB:-backup}" "$*"; }

# status file per job: /backups/status/<job>.status  ("ok <epoch> <bytes>" | "failed <epoch>") — read by monitoring / owner
write_status() {
  local dir="$BACKUP_DIR/status"; mkdir -p "$dir"
  local state="$1" size="${2:-0}"
  printf '%s %s %s\n' "$state" "$(date +%s)" "$size" > "$dir/${JOB}.status"
}
die() { log "ERROR: $*"; write_status failed 0; exit 1; }

# keep the newest N entries matching a glob, delete the rest
prune() {
  local dir="$1" glob="$2" keep="$3"
  [ -d "$dir" ] || return 0
  # an unmatched glob stays literal (no nullglob here) and makes `ls` fail — harmless (nothing to prune yet), but
  # under `set -o pipefail` that failure would otherwise abort the whole job; explicitly treat it as "nothing found"
  # shellcheck disable=SC2012
  ls -1t "$dir"/$glob 2>/dev/null | tail -n +"$((keep + 1))" | while read -r f; do log "retention: removing $f"; rm -rf -- "$f"; done || true
}
file_size() { stat -c %s "$1" 2>/dev/null || wc -c < "$1"; }
