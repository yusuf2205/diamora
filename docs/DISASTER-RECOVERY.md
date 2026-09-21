# Disaster recovery

Targets: **RPO ≈ 5 min** with WAL archive (24 h worst case with dumps only) · **RTO ≈ 1–2 h** on new hardware.
Run every procedure once as a drill (BACKUP.md rule 4). All commands run in the repo directory on the NAS.

## 1. A container is broken / won't start
`docker compose ps` · `docker compose logs --tail=200 <service>` · `docker compose up -d --force-recreate <service>`.
Data is in bind mounts, so re-creating containers loses nothing. If an image is bad: `git checkout <last-good-tag> && docker compose up -d --build`.

## 2. Verify integrity at any time
```sh
docker compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT count(*) FROM ledger_balance_mismatches;"   # must be 0
docker compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT count(*) FROM stock_balance_mismatches;"    # must be 0
docker compose run --rm backup /opt/backup/verify.sh                                                                        # restores newest dump to a scratch DB
```
Also compare counts: `worker_profiles`, `worker_collaterals`, `worker_ledger_transactions`, `audit_logs`; and open a few collateral photos in the app (files come from MinIO).

## 3. Bad update / bad migration / wrong data change — restore the last dump
```sh
docker compose stop api worker web
docker compose exec postgres psql -U $POSTGRES_USER -d postgres -c "CREATE DATABASE ${POSTGRES_DB}_restore;"
docker compose run --rm backup /opt/backup/restore.sh /backups/postgres/daily/<newest>.dump ${POSTGRES_DB}_restore
# check the restored data (section 2 queries against ${POSTGRES_DB}_restore), then swap:
docker compose exec postgres psql -U $POSTGRES_USER -d postgres -c "ALTER DATABASE ${POSTGRES_DB} RENAME TO ${POSTGRES_DB}_broken;"
docker compose exec postgres psql -U $POSTGRES_USER -d postgres -c "ALTER DATABASE ${POSTGRES_DB}_restore RENAME TO ${POSTGRES_DB};"
docker compose up -d && sh infra/scripts/verify-stack.sh
```
`restore.sh` refuses a non-empty target and a checksum mismatch; nothing is dropped automatically — the broken database stays as `_broken` until you delete it.

## 4. Point-in-time recovery (PITR) — "return to 14:20 yesterday"
Needs a base backup (`${BACKUP_ROOT}/postgres/base/base-*/`, weekly) and the WAL archive.
```sh
docker compose stop api worker web postgres
mv ${DATA_ROOT}/postgres ${DATA_ROOT}/postgres.broken && mkdir ${DATA_ROOT}/postgres && chown 999:999 ${DATA_ROOT}/postgres
mkdir -p ${DATA_ROOT}/postgres/pgdata
tar -xzf ${BACKUP_ROOT}/postgres/base/base-<newest before the target>/base.tar.gz -C ${DATA_ROOT}/postgres/pgdata
touch ${DATA_ROOT}/postgres/pgdata/recovery.signal
cat >> ${DATA_ROOT}/postgres/pgdata/postgresql.auto.conf <<'EOF'
restore_command = 'cp /wal-archive/%f %p'
recovery_target_time = '2026-09-21 09:20:00+00'
recovery_target_action = 'promote'
EOF
chown -R 999:999 ${DATA_ROOT}/postgres
docker compose up -d postgres        # watch: docker compose logs -f postgres  ("recovery stopping before commit…", then ready)
sh infra/scripts/verify-stack.sh && docker compose up -d
```
Choose the recovery time in UTC just before the mistake. Data created after that moment is lost — export anything you still need from `postgres.broken` first.

## 5. The NAS is dead / replaced (rebuild from scratch)
1. Install Docker/Compose on the new NAS; create volumes; attach the **backup disk** (or copy `BACKUP_ROOT` over).
2. `git clone` the repo. Restore `.env` from the password manager (or `age -d -i <private key> env-<ts>.age > .env`). Adjust `DATA_ROOT/BACKUP_ROOT` if paths changed.
3. `sh infra/scripts/nas-init.sh` (creates directories; keeps your `.env`).
4. Start only the data services: `docker compose up -d postgres redis minio` then `docker compose run --rm minio-init`.
5. Restore the database: section 3 (dump) or section 4 (PITR). *Empty database needed:* on a fresh install the migrator created the schema — either drop and recreate the database or restore into `${POSTGRES_DB}_restore` and rename as in section 3.
6. Restore files: `mc mirror` from the backup back into MinIO:
   ```sh
   docker compose run --rm --entrypoint sh backup -c 'export MC_CONFIG_DIR=/tmp/.mc; mc alias set dst http://minio:9000 "$S3_ACCESS_KEY" "$S3_SECRET_KEY" && for b in collateral assignments products quality documents avatars; do mc mirror --preserve /backups/minio/$b dst/$b; done'
   ```
   (uses the app identity; add `S3_ACCESS_KEY/S3_SECRET_KEY` to the backup service environment for this one-off, or use the MinIO root credentials.)
7. `docker compose up -d`, `sh infra/scripts/verify-stack.sh`, then the section 2 checks. Point DNS/port forwarding at the new NAS. Phones reconnect by themselves (JWT sessions are in the database; refresh tokens keep working).

## 6. Lost `.env`
Secrets can be regenerated but **old ones cannot be recovered**: new `JWT_ACCESS_SECRET` signs everyone out (fine), new `FILE_SIGNING_SECRET` invalidates old photo links (fine), but changing `POSTGRES_PASSWORD`/`MINIO_*` on existing data needs `ALTER ROLE`/MinIO user re-creation (`minio-init` re-adds users on start). Keep `.env` safe.

## 7. After any recovery
Rotate secrets if a leak is suspected, review `audit_logs` for the period, tell workers to re-enter the Telegram login code if sessions were reset, and note the incident + drill date in `docs/MVP-ROADMAP.md`.
