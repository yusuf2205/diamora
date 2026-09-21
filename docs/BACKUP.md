# Backup

All backups stay under OUR control (D-019). A cloud copy may only ever be an *additional* encrypted copy, added by a separate owner decision — never primary storage.

## What runs (container `backup`, times are UTC = Tashkent − 5 h)

| Job | Default schedule | What | Retention |
|---|---|---|---|
| `pg-dump.sh` | daily 21:00 | `pg_dump -Fc` + sha256, archive integrity check (`pg_restore --list`) | 7 daily · 4 weekly (Sun) · 6 monthly (1st) |
| WAL archive | continuous | PostgreSQL `archive_command` → `${BACKUP_ROOT}/postgres/wal` (≤ 5 min of unarchived WAL) | pruned with base backups |
| `pg-basebackup.sh` | weekly Sun 22:00 | physical base backup → point-in-time recovery | 3 |
| `minio-backup.sh` | daily 21:30 | `mc mirror` of every bucket with the **read-only** backup identity; deletions are *not* propagated | forever (mirror) |
| `config-backup.sh` | daily 21:45 | compose, proxy/DB configs, Dockerfiles, migrations; `.env` **only encrypted with age** if `BACKUP_AGE_RECIPIENT` is set | 7 |
| `verify.sh` | daily 22:30 | **restores the newest dump into a scratch database**, compares row counts, runs the ledger and stock self-checks, drops it | — |

Every job writes `${BACKUP_ROOT}/status/<job>.status` (`ok <epoch> <bytes>` / `failed <epoch>`). Check them: `cat ${BACKUP_ROOT}/status/*.status`. A dump is taken automatically 90 s after the very first start.

Run any job by hand: `docker compose run --rm backup /opt/backup/pg-dump.sh` (or `verify.sh`, `minio-backup.sh`, …).

## Rules that keep it honest
1. **`BACKUP_ROOT` must be a different physical disk** (or another NAS/USB disk) than `DATA_ROOT`. Backups on the same disk protect from mistakes, not from disk failure.
2. Enable **NAS snapshots** (Btrfs/ZFS) on both shares — they are the fast undo for "I deleted a folder".
3. `.env` is not in Git and not in clear text in the backups. Keep it in a password manager; optionally set `BACKUP_AGE_RECIPIENT` (public key from `age-keygen`, private key kept offline).
4. Once a quarter do a **restore drill** on a spare machine following DISASTER-RECOVERY.md and note the date.
5. Watch free space and the `status` files; a failing job never deletes older good backups (retention runs only after success).

## What is protected from what
| Event | Protected by |
|---|---|
| deleted/overwritten photo | MinIO versioning on `collateral`, `documents`, `quality` + mirror without delete propagation + NAS snapshot |
| bad migration / wrong data change | nightly dump, or PITR to a moment before the change |
| corrupted container/image | rebuild from Git; data untouched on bind mounts |
| dead NAS | everything on `BACKUP_ROOT` + `.env` → DISASTER-RECOVERY.md §5 |
| someone edits history | impossible through the app; DB triggers make ledger, collateral history, stock movements, status history and audit log append-only |
