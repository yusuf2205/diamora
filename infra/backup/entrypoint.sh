#!/usr/bin/env bash
# Writes the crontab from environment variables and runs busybox crond. With arguments it just runs them
# (`docker compose run --rm backup /opt/backup/verify.sh`).
set -euo pipefail
if [ "$#" -gt 0 ]; then exec "$@"; fi

cat > /etc/crontabs/root <<EOF
# generated at container start (UTC)
* * * * * touch /tmp/scheduler.alive
${BACKUP_SCHEDULE_DUMP:-0 21 * * *}   /opt/backup/pg-dump.sh      >> /proc/1/fd/1 2>&1
${BACKUP_SCHEDULE_CONFIG:-45 21 * * *} /opt/backup/config-backup.sh >> /proc/1/fd/1 2>&1
${BACKUP_SCHEDULE_MINIO:-30 21 * * *} /opt/backup/minio-backup.sh  >> /proc/1/fd/1 2>&1
${BACKUP_SCHEDULE_BASE:-0 22 * * 0}   /opt/backup/pg-basebackup.sh >> /proc/1/fd/1 2>&1
${BACKUP_SCHEDULE_VERIFY:-30 22 * * *} /opt/backup/verify.sh        >> /proc/1/fd/1 2>&1
EOF
# crond does not inherit the container environment: persist what the jobs need (sourced by lib.sh)
env | grep -E '^(PG|S3_|BACKUP_|RETENTION_|REPO_|TZ)' | sed 's/^/export /; s/=/="/; s/$/"/' > /tmp/backup-env.sh
chmod 600 /tmp/backup-env.sh
touch /tmp/scheduler.alive
echo "backup scheduler started (UTC): dump='${BACKUP_SCHEDULE_DUMP:-}' minio='${BACKUP_SCHEDULE_MINIO:-}' base='${BACKUP_SCHEDULE_BASE:-}' verify='${BACKUP_SCHEDULE_VERIFY:-}'"
# first start: take a dump right away so a fresh installation is protected from minute one
( sleep 90; [ -z "$(ls -A "${BACKUP_DIR:-/backups}/postgres/daily" 2>/dev/null)" ] && /opt/backup/pg-dump.sh ) >> /proc/1/fd/1 2>&1 &
exec crond -f -l 8
