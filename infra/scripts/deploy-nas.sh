#!/bin/sh
# Ship the current working tree to the NAS, then build, start and verify the stack there (infra/scripts/nas-remote.sh).
#   sh infra/scripts/deploy-nas.sh <user>@<nas-address> [remote-dir]          (default remote-dir: /volume1/docker/yusmus)
# Optional environment variables:
#   PUBLIC_URL   how phones reach the stack, first installation only   (default http://<nas-address>:8088)
#   HTTP_BIND    0.0.0.0 = reachable from the home network / Tailscale (default), 127.0.0.1 = NAS itself + tunnel only
#   ADMIN_PHONE, ADMIN_NAME   also create the ADMIN account (its password is shown once)
# Needs ssh + tar on THIS computer (Git Bash has both) and Docker on the NAS. It asks for the NAS password twice
# (one connection uploads, one installs). .env is never uploaded: the NAS generates its own secrets on the first run
# and takes TELEGRAM_BOT_TOKEN from the .env of this computer. Later runs are updates. Example for our NAS:
#   PUBLIC_URL=http://192.168.1.105:8088 ADMIN_PHONE=+998908074144 ADMIN_NAME="Owner" sh infra/scripts/deploy-nas.sh Joseph@100.126.164.29
set -eu
HOST="${1:?usage: sh infra/scripts/deploy-nas.sh <user>@<nas-address> [remote-dir]}"
DIR="${2:-/volume1/docker/yusmus}"
ADDR="${HOST#*@}"
cd "$(dirname "$0")/../.."

echo "==> uploading the source to $HOST:$DIR (no .env, no node_modules, no mobile app)"
tar czf - --exclude=node_modules --exclude=.git --exclude=.dev-data --exclude=.env --exclude=dist --exclude=.next --exclude=.turbo \
  --exclude=apps/mobile --exclude='*.log' --exclude=.tmp --exclude=.claude --exclude=.vscode . \
  | ssh "$HOST" "mkdir -p '$DIR' && tar xzf - -C '$DIR'"

TOKEN=""
[ -f .env ] && TOKEN="$(sed -n 's/^TELEGRAM_BOT_TOKEN=//p' .env | head -n1)"
echo "==> installing on the NAS"
{
  echo "PUBLIC_URL=${PUBLIC_URL:-http://$ADDR:8088}"
  echo "HTTP_BIND=${HTTP_BIND:-0.0.0.0}"
  [ -z "$TOKEN" ] || echo "TELEGRAM_BOT_TOKEN=$TOKEN"
  if [ -n "${ADMIN_PHONE:-}" ]; then echo "ADMIN_PHONE=$ADMIN_PHONE"; echo "ADMIN_NAME=${ADMIN_NAME:-Owner}"; fi
} | ssh "$HOST" "sh '$DIR/infra/scripts/nas-remote.sh'"
