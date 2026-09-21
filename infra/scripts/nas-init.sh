#!/bin/sh
# First-time preparation of the NAS (POSIX sh: works in Synology/QNAP/TrueNAS shells).   sh infra/scripts/nas-init.sh [DATA_ROOT] [BACKUP_ROOT]
# Creates the persistent directory tree with the right owners, and .env from .env.example with FRESH random secrets
# (never overwrites an existing .env). Safe to re-run.
set -eu
cd "$(dirname "$0")/../.."
DATA_ROOT="${1:-${DATA_ROOT:-/data/production}}"
BACKUP_ROOT="${2:-${BACKUP_ROOT:-/data/backups}}"
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1"; exit 1; }; }
need openssl; need docker
rand() { openssl rand -hex "${1:-24}"; }

echo "==> creating directories under $DATA_ROOT and $BACKUP_ROOT"
mkdir -p "$DATA_ROOT"/postgres "$DATA_ROOT"/redis "$DATA_ROOT"/minio "$DATA_ROOT"/caddy/data "$DATA_ROOT"/caddy/config "$DATA_ROOT"/logs
mkdir -p "$BACKUP_ROOT"/postgres/daily "$BACKUP_ROOT"/postgres/weekly "$BACKUP_ROOT"/postgres/monthly "$BACKUP_ROOT"/postgres/base \
         "$BACKUP_ROOT"/postgres/wal "$BACKUP_ROOT"/minio "$BACKUP_ROOT"/config "$BACKUP_ROOT"/status
# postgres (Debian image) and redis (alpine image) both run as uid 999
if chown 999:999 "$DATA_ROOT"/postgres "$DATA_ROOT"/redis "$BACKUP_ROOT"/postgres/wal 2>/dev/null; then
  chmod 700 "$DATA_ROOT"/postgres "$BACKUP_ROOT" 2>/dev/null || true
else
  # Not root (the usual NAS admin account): let Docker do it — a throw-away container runs as root and sees the same folders.
  echo "==> not root: setting ownership (uid 999) through a throw-away container"
  docker run --rm --entrypoint sh -v "$DATA_ROOT:/data" -v "$BACKUP_ROOT:/backup" "${POSTGRES_IMAGE:-postgres:17-bookworm}" \
    -c 'chown 999:999 /data/postgres /data/redis /backup/postgres/wal && chmod 700 /data/postgres /backup' \
    || echo "note: could not set ownership; run: chown 999:999 $DATA_ROOT/postgres $DATA_ROOT/redis $BACKUP_ROOT/postgres/wal"
fi

if [ -f .env ]; then
  echo "==> .env already exists — leaving it untouched"
else
  echo "==> generating .env with fresh secrets"
  cp .env.example .env
  set_var() { sed -i "s|^$1=.*|$1=$2|" .env; }
  set_var DATA_ROOT "$DATA_ROOT"; set_var BACKUP_ROOT "$BACKUP_ROOT"
  set_var POSTGRES_PASSWORD "$(rand)"; set_var BACKUP_DB_PASSWORD "$(rand)"; set_var REDIS_PASSWORD "$(rand)"
  set_var MINIO_ROOT_USER "minio-root-$(rand 4)"; set_var MINIO_ROOT_PASSWORD "$(rand)"
  set_var S3_SECRET_KEY "$(rand)"; set_var S3_BACKUP_SECRET_KEY "$(rand)"
  set_var JWT_ACCESS_SECRET "$(rand 32)"; set_var FILE_SIGNING_SECRET "$(rand 32)"
  chmod 600 .env
  echo "    .env created (mode 600)."
fi

cat <<EOF

Next steps
  1. Edit .env: PUBLIC_URL, HTTP_BIND, TELEGRAM_BOT_TOKEN (and CLOUDFLARE_TUNNEL_TOKEN for internet HTTPS).
  2. BACK UP .env NOW (password manager / offline media) — see docs/DISASTER-RECOVERY.md.
  3. docker compose config -q          # validates the stack
  4. docker compose up -d --build      # first start builds the images (10-20 min on a NAS)
  5. sh infra/scripts/verify-stack.sh  # smoke test: health, persistence, nothing dangerous exposed
  6. Create the ADMIN account:
       docker compose run --rm api dist/cli/bootstrap.js --name "Owner" --phone "+998..."
EOF
