#!/bin/sh
# Runs ON the NAS (started by deploy-nas.sh from the development computer). Reads KEY=VALUE lines from stdin
# (PUBLIC_URL, HTTP_BIND, TELEGRAM_BOT_TOKEN, ADMIN_PHONE, ADMIN_NAME) so that no secret ever appears on a command line.
# First installation (no .env yet): folders + owners + random secrets + the values above. Every run: build, start, verify.
set -eu
cd "$(dirname "$0")/../.."
DIR="$(pwd)"
CFG="$(cat)"
cfg() { printf '%s\n' "$CFG" | sed -n "s/^$1=//p" | head -n1; }

if [ ! -f .env ]; then
  echo "==> first installation: folders, random secrets, .env"
  sh infra/scripts/nas-init.sh "$DIR/data" "$DIR/backups"
  for k in PUBLIC_URL HTTP_BIND TELEGRAM_BOT_TOKEN; do
    v="$(cfg "$k")"
    [ -n "$v" ] || continue
    sed -i "s|^$k=.*|$k=$v|" .env
  done
  if grep -q '^TELEGRAM_BOT_TOKEN=CHANGE_ME' .env; then
    echo "TELEGRAM_BOT_TOKEN is missing: put it into .env of this computer (or into $DIR/.env) and run again"
    exit 1
  fi
fi

echo "==> validating and starting the stack (the first build takes 10-20 minutes)"
docker compose config -q
docker compose up -d --build
sh infra/scripts/verify-stack.sh

phone="$(cfg ADMIN_PHONE)"
if [ -n "$phone" ]; then
  echo "==> creating the ADMIN account (the password is shown ONCE)"
  docker compose run --rm -T api dist/cli/bootstrap.js --name "$(cfg ADMIN_NAME)" --phone "$phone"
fi
