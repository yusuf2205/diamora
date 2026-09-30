# Восстановление с внешнего диска / Restoring from the external drive

## RU — для владельца

**Что лежит на диске.** Каждую ночь (23:00 UTC = 04:00 Ташкент) NAS копирует на внешний диск, в папку
`diamoraa-backup`:

| Папка | Что это | Удаляется само? |
|---|---|---|
| `postgres/daily`, `weekly`, `monthly` | копии базы данных (мастерицы, работы, деньги, чат…) | **нет** — это длинная история; лишнее удаляет Супер админ в панели: **Система → Внешний диск** |
| `postgres/base` | самая свежая полная копия базы | заменяется новой каждую неделю |
| `minio` | фото и файлы (залоги, каталог, чат) | обновляется каждую ночь |
| `config` | настройки сервера (без паролей в открытом виде, если включено шифрование) | обновляется каждую ночь |

Не удаляйте файл `.diamoraa-offsite` — по нему NAS находит этот диск. Остальные ваши файлы на диске NAS не трогает.

**Когда восстанавливать.** Только если сломались диски NAS или данные испорчены. В обычной жизни ничего делать не нужно.

**Что делать.**
1. Ничего не удаляйте и не форматируйте на внешнем диске.
2. NAS работает → напишите разработчику: «восстанови базу от <дата>» (даты — в списке «Система → Внешний диск»).
3. NAS сломан → отключите диск, подключите к новому NAS или компьютеру и передайте разработчику.
4. Восстановление всегда идёт **в новую пустую базу**: текущие данные не стираются, пока вы не проверите, что всё на месте.

## EN — for the developer

Everything below runs on the NAS in `/volume1/docker/yusmus` (or a fresh install of this repository). `USB=/mnt/@usb/<drive>/diamoraa-backup`.

**1. Database** — into an EMPTY database, never over the live one (`restore.sh` refuses a non-empty target and checks `.sha256`):

```sh
docker compose exec postgres psql -U $POSTGRES_USER -d postgres -c "CREATE DATABASE ${POSTGRES_DB}_restore;"
docker compose run --rm -v "$USB:/usb:ro" backup /opt/backup/restore.sh /usb/postgres/daily/<file>.dump ${POSTGRES_DB}_restore
# check it (docs/DISASTER-RECOVERY.md §2), then swap names as in DISASTER-RECOVERY.md §3
```

**2. Photos & files** — back into MinIO (no deletions):

```sh
docker compose run --rm -v "$USB:/usb:ro" --entrypoint sh backup -c 'export MC_CONFIG_DIR=/tmp/.mc; mc alias set dst http://minio:9000 "$S3_ACCESS_KEY" "$S3_SECRET_KEY" && for b in collateral assignments products quality documents avatars chat; do mc mirror --preserve /usb/minio/$b dst/$b; done'
```

**3. Settings** — `config/config-<date>.tar.gz` holds `.env` and the compose files (age-encrypted when `BACKUP_AGE_RECIPIENT`
is set). A full rebuild on new hardware: `docs/DISASTER-RECOVERY.md` §5, using this drive instead of `/backups`.

**Point-in-time recovery** needs the WAL archive, which stays on the NAS only (too large for the drive); the drive
gives «as of any nightly copy».

The nightly job is `infra/backup/offsite-copy.sh`; its state is `status/offsite.status` (`ok` / `nodrive` / `full` /
`failed`), shown in «Система» and sent to the owner's Telegram once a day when not `ok`.
