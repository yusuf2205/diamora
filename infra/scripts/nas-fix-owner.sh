#!/bin/sh
# Runs ON the NAS (deploy-nas.sh / publish-apk.sh pipe it over ssh: `ssh host sh -s -- <dir> < this file`).
# The NAS (UGREEN) hands the project folder to root:root whenever its Docker app restarts; the deploy user then can no
# longer read .env or update the source. This gives the SOURCE/CONFIG files back to the deploy user — the same way
# nas-init.sh sets data ownership: through a throw-away container (the deploy user has Docker, not sudo).
# Never touched: data/ (postgres/redis/minio files, uid 999 etc.) and backups/ — except data's published APK folder.
# Symlinks are never followed (chown -h, find without -L): a link cannot be used to re-own anything outside.
set -eu
DIR="${1:?usage: nas-fix-owner.sh <project-dir>}"
[ -d "$DIR" ] || exit 0 # first installation: nothing to fix
me_uid="$(id -u)"; me_gid="$(id -g)"
IMAGE="${FIX_IMAGE:-postgres:17-bookworm}" # already on the NAS (the database image); no download needed

needs=0
[ "$(stat -c %u "$DIR")" = "$me_uid" ] || needs=1
[ ! -e "$DIR/.env" ] || [ -r "$DIR/.env" ] || needs=1
[ -z "$(find "$DIR" -xdev \( -path "$DIR/data" -o -path "$DIR/backups" \) -prune -o ! -user "$me_uid" -print 2>/dev/null | head -n 1)" ] || needs=1
if [ "$needs" = 0 ]; then echo "==> ownership ok"; exit 0; fi

echo "==> the NAS re-owned the project folder: giving source/config back to $(id -un) (data/ and backups/ untouched)"
docker run --rm --entrypoint sh -v "$DIR:/p" "$IMAGE" -c "
  set -e; cd /p
  find . -xdev \\( -path ./data -o -path ./backups \\) -prune -o -exec chown -h $me_uid:$me_gid {} +
  if [ -f .env ] && [ ! -L .env ]; then chmod 600 .env; fi
"
# the published APKs live in \$DATA_ROOT/downloads (Caddy serves them); only that folder, never the rest of data/
DATA_ROOT="$(sed -n 's/^DATA_ROOT=//p' "$DIR/.env" 2>/dev/null | tail -n1)"
if [ -n "$DATA_ROOT" ] && [ -d "$DATA_ROOT/downloads" ] && [ ! -L "$DATA_ROOT/downloads" ] && [ "$(stat -c %u "$DATA_ROOT/downloads")" != "$me_uid" ]; then
  docker run --rm --entrypoint chown -v "$DATA_ROOT/downloads:/d" "$IMAGE" -hR "$me_uid:$me_gid" /d
fi
[ -r "$DIR/.env" ] && echo "==> ownership fixed" || { echo "ownership could not be fixed" >&2; exit 1; }
