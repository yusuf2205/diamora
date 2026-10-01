#!/bin/sh
# Publishes the training videos to the NAS: https://<site>/download/tutorials/ (Caddy serves ${DATA_ROOT}/downloads).
#   node manifest.mjs && sh publish.sh <user@nas>          (from tools/tutorials)
# Every file goes up to a temp name and replaces the live one only when its checksum matches; the manifest goes last,
# so the app and the panel never list a video that is not there yet.
set -eu
HOST="${1:?usage: publish.sh <user@nas>}"
DIR="${DIR:-/volume1/docker/yusmus}"
KEY="${SSH_KEY:-$HOME/.ssh/yusmus_deploy}"
SSH="ssh -i $KEY -o BatchMode=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=8 $HOST"
OUT="${OUT:-out}"
[ -f "$OUT/tutorials.json" ] || { echo "run: node manifest.mjs" >&2; exit 1; }

DATA_ROOT="$($SSH "sed -n 's/^DATA_ROOT=//p' $DIR/.env" | tail -n1)"
[ -n "$DATA_ROOT" ] || { echo "DATA_ROOT not found in $DIR/.env" >&2; exit 1; }
DEST="$DATA_ROOT/downloads/tutorials"
$SSH "mkdir -p '$DEST'"

put() { # <local file>
  name="$(basename "$1")"
  sum="$(sha256sum "$1" | cut -d' ' -f1)"
  if [ "$($SSH "sha256sum '$DEST/$name' 2>/dev/null | cut -d' ' -f1" || true)" = "$sum" ]; then echo "    = $name"; return 0; fi
  echo "==> $name ($(du -h "$1" | cut -f1))"
  $SSH "cat > '$DEST/.$name.tmp' && [ \"\$(sha256sum '$DEST/.$name.tmp' | cut -d' ' -f1)\" = '$sum' ] && mv '$DEST/.$name.tmp' '$DEST/$name' || { rm -f '$DEST/.$name.tmp'; echo 'upload incomplete' >&2; exit 1; }" < "$1"
}
for f in "$OUT"/*.mp4 "$OUT"/*.jpg; do [ -f "$f" ] && put "$f"; done
put "$OUT/tutorials.json"
echo "==> published: https://diamoraa.uz/download/tutorials/tutorials.json"
