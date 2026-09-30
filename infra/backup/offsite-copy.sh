#!/usr/bin/env bash
# Copy of the backups on the EXTERNAL drive plugged into the NAS (owner, 2026-10-01): if the NAS disks die, the data
# still exists. USB drives are mounted under /usb (the NAS's /mnt/@usb, bind-mounted with rslave so a drive plugged in
# later appears too). The target is the folder that holds the marker file `.diamoraa-offsite` on any of those drives -
# created once on purpose, so an unplugged drive is never «replaced» by an empty folder and nothing else on the drive
# is ever touched. Copied: daily/weekly/monthly database dumps, the newest full base copy, photos & files, settings.
# Not copied: the WAL archive (large; point-in-time restore stays on the NAS).
# shellcheck source=lib.sh
. /opt/backup/lib.sh
JOB=offsite

USB_ROOT="${OFFSITE_USB_ROOT:-/usb}"
target=""
for marker in "$USB_ROOT"/*/diamoraa-backup/.diamoraa-offsite; do
  [ -f "$marker" ] && { target="$(dirname "$marker")"; break; }
done
if [ -z "$target" ]; then
  log "no external drive with diamoraa-backup/.diamoraa-offsite under $USB_ROOT - is the drive plugged in?"
  write_status nodrive 0
  exit 1
fi
log "copying to $target"

# NTFS / exFAT drives keep no Unix owners or permissions: plain copies, same names, newer wins; a file removed here by
# retention is removed there too (mirror), so the drive never fills up with years of old dumps.
mirror() { # <from> <to>
  local from="$1" to="$2"
  [ -d "$from" ] || return 0
  mkdir -p "$to"
  # new / changed files
  (cd "$from" && find . -type f) | while read -r f; do
    if [ ! -f "$to/$f" ] || [ "$(file_size "$from/$f")" != "$(file_size "$to/$f")" ] || [ "$from/$f" -nt "$to/$f" ]; then
      mkdir -p "$(dirname "$to/$f")"
      cp -f -- "$from/$f" "$to/$f.part" && mv -f -- "$to/$f.part" "$to/$f"
    fi
  done
  # gone here -> gone there
  (cd "$to" && find . -type f ! -name '*.part') | while read -r f; do
    [ -f "$from/$f" ] || rm -f -- "$to/$f"
  done
  find "$to" -mindepth 1 -type d -empty -delete 2>/dev/null || true
}

for d in daily weekly monthly; do mirror "$BACKUP_DIR/postgres/$d" "$target/postgres/$d" || die "copy postgres/$d failed"; done
# only the newest full base copy (with its own WAL inside): enough to rebuild, small enough for a USB drive
newest_base="$(ls -1dt "$BACKUP_DIR"/postgres/base/base-* 2>/dev/null | head -n1 || true)"
if [ -n "$newest_base" ]; then
  rm -rf "$target/postgres/base.new" && mkdir -p "$target/postgres"
  mirror "$newest_base" "$target/postgres/base.new/$(basename "$newest_base")" || die "copy base failed"
  rm -rf "$target/postgres/base" && mv "$target/postgres/base.new" "$target/postgres/base"
fi
mirror "$BACKUP_DIR/minio" "$target/minio" || die "copy minio failed"
mirror "$BACKUP_DIR/config" "$target/config" || die "copy config failed"

printf 'Резервная копия Diamoraa. Последнее обновление: %s (UTC)\nВосстановление: docs в репозитории, infra/backup/restore.sh\n' "$(date -u '+%Y-%m-%d %H:%M')" > "$target/ПРОЧТИ.txt"
bytes="$(du -sb "$target" 2>/dev/null | cut -f1 || echo 0)"
log "done: $bytes bytes on the external drive"
write_status ok "$bytes"
