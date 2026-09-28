#!/bin/sh
# Runs ON the NAS before anything is uploaded (deploy-nas.sh pipes it over ssh: `ssh host sh -s -- <dir> < this file`).
# Aborts the deploy BEFORE production is touched when ownership is wrong. Background: on 2026-09-25 00:30 something on
# the NAS (not our scripts) chowned the whole project root:root; postgres (uid 999) lost its files and the API crash-looped.
#   exit 0 = safe to deploy (or first installation), exit 1 = fix what is printed first
set -u
DIR="${1:?usage: nas-preflight.sh <project-dir>}"
me="$(id -un)"
bad=0
fail() { echo "  FAIL: $*"; bad=1; }
ok() { echo "  ok: $*"; }

echo "==> preflight on $(hostname) as $me: $DIR"
if [ ! -e "$DIR" ]; then
  parent="$(dirname "$DIR")"
  [ -w "$parent" ] && ok "first installation, $parent is writable" || fail "$parent is not writable for $me"
  exit $bad
fi

owner="$(stat -c %U "$DIR")"
[ "$owner" = "$me" ] && ok "project folder owned by $me" || fail "project folder is owned by $owner, not $me"
[ -w "$DIR" ] && ok "project folder writable" || fail "project folder is not writable for $me"
# source files the upload overwrites: every one must belong to the deploy user
foreign="$(find "$DIR" -xdev \( -path "$DIR/data" -o -path "$DIR/backups" \) -prune -o ! -user "$me" -print 2>/dev/null | head -n 5)"
[ -z "$foreign" ] && ok "all source/config files owned by $me" || fail "files not owned by $me, e.g.: $(echo "$foreign" | tr '\n' ' ')"
if [ -f "$DIR/.env" ]; then
  [ -r "$DIR/.env" ] && [ -w "$DIR/.env" ] && ok ".env readable and writable" || fail ".env is not readable/writable for $me"
  perm="$(stat -c %a "$DIR/.env")"
  [ "$perm" = 600 ] && ok ".env mode 600" || fail ".env mode is $perm, expected 600"
fi

# data owned by the containers' own users (postgres/redis run as uid 999); never by root
for d in data/postgres data/redis; do
  [ -e "$DIR/$d" ] || continue
  uid="$(stat -c %u "$DIR/$d")"
  [ "$uid" = 999 ] && ok "$d owned by uid 999" || fail "$d owned by uid $uid, expected 999 (postgres/redis would crash)"
done
if [ -e "$DIR/backups" ]; then
  [ -d "$DIR/backups" ] && ok "backups folder present" || fail "backups is not a folder"
fi

# the running database can really read its files (host-side ls is denied by design: the dir is 700 for uid 999)
# (by label, not `docker compose`: compose needs .env, which is exactly what may be unreadable here)
pg="$(docker ps -q --filter "label=com.docker.compose.project=$(basename "$DIR")" --filter label=com.docker.compose.service=postgres 2>/dev/null)"
if [ -n "$pg" ]; then
  if docker exec "$pg" sh -c 'test -r "$PGDATA/global/pg_filenode.map" && test -w "$PGDATA"' 2>/dev/null; then
    ok "postgres can read and write its data"
  else
    fail "postgres cannot read/write its data directory"
  fi
fi

if [ $bad -ne 0 ]; then
  echo "==> preflight FAILED: nothing was changed on the NAS. Fix ownership (source/config -> $me, data/postgres + data/redis -> 999) and rerun."
fi
exit $bad
