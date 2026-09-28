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
# The app updates itself from this manifest (apps/mobile/lib/core/update/app_updater.dart): build = the +N of
# pubspec.yaml; sha256 lets the phone throw away a broken download instead of offering it for install.
BUILD="$(sed -n 's/^version: *[^+]*+\([0-9]*\).*/\1/p' apps/mobile/pubspec.yaml | head -n1)"
[ -n "$BUILD" ] || { echo "build number not found in apps/mobile/pubspec.yaml" >&2; exit 1; }
sha() { sha256sum "$1" | cut -d' ' -f1; }
printf '{"version":"%s","build":%s,"publishedAt":"%s","files":{"arm64":{"path":"/download/diamoraa.apk","sha256":"%s"},"armv7":{"path":"/download/diamoraa-armv7.apk","sha256":"%s"}}}\n' \
  "$VERSION" "$BUILD" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(sha "$OUT/app-arm64-v8a-release.apk")" "$(sha "$OUT/app-armeabi-v7a-release.apk")" \
  | $SSH "cat > '$DATA_ROOT/downloads/.version.json.tmp' && mv '$DATA_ROOT/downloads/.version.json.tmp' '$DATA_ROOT/downloads/version.json'"
echo "==> published $VERSION (build $BUILD)"
