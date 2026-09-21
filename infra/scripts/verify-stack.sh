#!/bin/sh
# Smoke test of a RUNNING stack on the NAS (after `docker compose up -d`). Exits non-zero on the first failure.
#   sh infra/scripts/verify-stack.sh [--restart]     --restart also restarts the stateful containers and proves data survives
set -eu
cd "$(dirname "$0")/../.."
ok()   { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; exit 1; }
dc()   { docker compose "$@"; }
# shellcheck disable=SC1091
. ./.env

echo "== containers healthy"
for svc in postgres redis minio api worker web caddy backup; do
  status="$(dc ps --format '{{.Service}} {{.Health}} {{.State}}' | awk -v s="$svc" '$1==s {print $2 " " $3}')"
  case "$status" in *healthy*) ok "$svc" ;; *) fail "$svc is not healthy ($status)" ;; esac
done
for job in migrate minio-init; do
  code="$(docker inspect -f '{{.State.ExitCode}}' "$(dc ps -aq "$job" | head -n1)")"
  [ "$code" = "0" ] && ok "$job completed" || fail "$job exit code $code"
done

echo "== readiness (database + files + redis reachable from the API)"
dc exec -T api node -e "fetch('http://127.0.0.1:3000/health/ready').then(async r=>{console.log(JSON.stringify(await r.json()));process.exit(r.ok?0:1)})" && ok "api /health/ready" || fail "api not ready"

echo "== nothing dangerous is published"
published="$(docker ps --format '{{.Names}} {{.Ports}}')"
echo "$published" | grep -E 'postgres|redis' | grep -qE '0\.0\.0\.0|:::' && fail "PostgreSQL/Redis port is published!" || ok "postgres/redis not published"
echo "$published" | grep -E 'minio' | grep -E '0\.0\.0\.0|:::' && fail "MinIO is published to all interfaces!" || ok "minio console bound to localhost only"

echo "== reverse proxy exposes only what it should (http://127.0.0.1:${HTTP_PORT:-8088})"
code() { curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${HTTP_PORT:-8088}$1" || true; }
[ "$(code /api/health)" = "200" ] && ok "GET /api/health -> web app reachable through the proxy" || fail "web app not reachable via proxy"
[ "$(code /health/live)" = "200" ] && ok "GET /health/live -> 200" || fail "/health/live not reachable via proxy"
[ "$(code /health/ready)" = "404" ] && ok "/health/ready blocked at proxy" || fail "/health/ready is reachable from outside!"
[ "$(code /v1/workers)" = "401" ] && ok "/v1/workers requires authentication" || fail "unauthenticated API access is not rejected"
[ "$(code /docs)" = "404" ] && ok "Swagger blocked at proxy" || fail "/docs is reachable from outside!"
# the tunnel is optional: check it only when it is running
if [ -n "$(dc ps -q cloudflared 2>/dev/null)" ]; then
  status="$(dc ps --format '{{.Service}} {{.Health}}' | awk '$1=="cloudflared" {print $2}')"
  [ "$status" = "healthy" ] && ok "cloudflared tunnel healthy" || fail "cloudflared is not healthy ($status)"
fi

echo "== persistent volumes hold data"
for d in postgres redis minio; do [ -n "$(ls -A "$DATA_ROOT/$d" 2>/dev/null)" ] && ok "$DATA_ROOT/$d populated" || fail "$DATA_ROOT/$d is empty"; done

if [ "${1:-}" = "--restart" ]; then
  echo "== restart persistence"
  before="$(dc exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -qAt -c 'SELECT count(*) FROM audit_logs')"
  dc restart postgres redis minio api worker
  i=0
  until dc exec -T api node -e "fetch('http://127.0.0.1:3000/health/ready').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" 2>/dev/null; do
    i=$((i+1)); [ "$i" -gt 40 ] && fail "stack did not come back within 200 s"; sleep 5
  done
  after="$(dc exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -qAt -c 'SELECT count(*) FROM audit_logs')"
  [ "$before" = "$after" ] && ok "data survived restart (audit rows: $after)" || fail "row count changed: $before -> $after"
fi
echo; echo "ALL CHECKS PASSED"
