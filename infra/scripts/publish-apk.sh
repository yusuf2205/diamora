#!/bin/sh
# Publishes the Android app for workers at https://<PUBLIC_URL>/download (served by Caddy from ${DATA_ROOT}/downloads).
#   sh infra/scripts/publish-apk.sh <user@nas> <version>
# Expects the split release build next to it:  flutter build apk --release --split-per-abi ... (apps/mobile)
#   app-arm64-v8a-release.apk   -> diamoraa.apk          (almost every phone today; what /download gives)
#   app-armeabi-v7a-release.apk -> diamoraa-armv7.apk    (old 32-bit phones; linked from the landing page)
# Upload is atomic (temp file + mv): a phone downloading at that moment never gets half a file.
set -eu
HOST="${1:?usage: publish-apk.sh <user@nas> <version>}"
VERSION="${2:?usage: publish-apk.sh <user@nas> <version>}"
DIR="${DIR:-/volume1/docker/yusmus}"
KEY="${SSH_KEY:-$HOME/.ssh/yusmus_deploy}"
OUT="apps/mobile/build/app/outputs/flutter-apk"
SSH="ssh -i $KEY -o BatchMode=yes $HOST"

DATA_ROOT="$($SSH "sed -n 's/^DATA_ROOT=//p' $DIR/.env" | tail -n1)"
[ -n "$DATA_ROOT" ] || { echo "DATA_ROOT not found in $DIR/.env" >&2; exit 1; }
$SSH "mkdir -p '$DATA_ROOT/downloads'"

put() { # <local file> <published name>
  [ -f "$1" ] || { echo "missing $1 (build with --split-per-abi first)" >&2; exit 1; }
  echo "==> $2 ($(du -h "$1" | cut -f1))"
  $SSH "cat > '$DATA_ROOT/downloads/.$2.tmp' && mv '$DATA_ROOT/downloads/.$2.tmp' '$DATA_ROOT/downloads/$2'" < "$1"
}
put "$OUT/app-arm64-v8a-release.apk" diamoraa.apk
put "$OUT/app-armeabi-v7a-release.apk" diamoraa-armv7.apk
printf '{"version":"%s","publishedAt":"%s"}\n' "$VERSION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" | $SSH "cat > '$DATA_ROOT/downloads/version.json'"
echo "==> published $VERSION"
