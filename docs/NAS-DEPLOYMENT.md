# NAS deployment

Everything runs on our NAS in Docker Compose (D-001). Files: `docker-compose.yml`, `.env.example`, `infra/`.

## 0. Our NAS (inspected over SSH on 2026-09-21, read-only)
| | |
|---|---|
| Device | UGREEN **DXP4800 Plus**, UGOS (Debian 12), Intel Pentium Gold 8505 (6 threads), **x86_64** — all images are plain amd64 |
| Memory / storage | **62 GB RAM**; `/volume1` 9.1 TB (HDD + SSD bcache) with ≈7.9 TB free; system NVMe; a 466 GB USB disk at `/mnt/@usb/sdd1` (NTFS-type: fine for copies of backups, **not** for PostgreSQL) |
| Docker | 29.6 + Compose 5.1; Docker root `/volume1/@docker`; the SSH user is in the `docker` group |
| Already running | ≈30 containers of other projects (procurement, gitea, yordam, nura, n8n, wordpress, 4× Cloudflare Tunnel …). Compose projects live in `/volume1/docker/<project>` → ours: `/volume1/docker/yusmus` |
| Host ports taken | **80, 443** (UGOS), 22, 222, 3000, 3001, 3005, 3100, 4100, 5888, 5999, 8000, 8011, 9449, 9999, 33308, 37487 …; loopback 5432/6379/8080. Free: **8088**, 8090, 8443 |
| Network | LAN `192.168.1.0/24` (NAS = 192.168.1.105), Tailscale 100.126.164.29, public IP seen from the NAS 144.124.192.241 — the ISP path has private hops (possible CGNAT), so **no port-forwarding is assumed** |
| Time zone | Asia/Karachi (UTC+5 = same as Tashkent); the stack itself runs in UTC |

Consequences (D-025): we publish **one** port (8088), never touch 80/443, pin our own Docker subnets and leave every other project alone.

## 1. First installation (one command)
The NAS has no copy of the code; `deploy-nas.sh` uploads it from the development computer and `nas-remote.sh` does the rest on the NAS: folders and owners (through Docker if you are not root), a `.env` with fresh random secrets, build, start, smoke test and — if you give a phone — the ADMIN account. `.env` is never uploaded; the bot token is taken from the `.env` of the development computer and sent over the SSH connection (not on a command line).
```sh
# Git Bash on the development computer, in the project folder (asks for the NAS password twice)
PUBLIC_URL=http://192.168.1.105:8088 ADMIN_PHONE=+998908074144 ADMIN_NAME="Owner"   sh infra/scripts/deploy-nas.sh Joseph@100.126.164.29
```
The first build takes 10–20 minutes. Afterwards, updates are the same command without `ADMIN_*`. The ADMIN password is printed once at the end: write it down and change it in the app.
**Immediately back up `.env`** (password manager / offline). It holds every secret; without it a restored database cannot be reconnected.

## 2. Layout on disk (all paths come from `.env`, nothing is hard-coded in the apps)
```
${DATA_ROOT}/postgres   PostgreSQL data (PGDATA)      ${BACKUP_ROOT}/postgres/{daily,weekly,monthly,base,wal}
${DATA_ROOT}/redis      Redis AOF (realtime bus)      ${BACKUP_ROOT}/minio/<bucket>/…   (mirror, deletions NOT propagated)
${DATA_ROOT}/minio      files (photos, schemes)       ${BACKUP_ROOT}/config/   ${BACKUP_ROOT}/status/
${DATA_ROOT}/caddy      proxy state
```
Persistent data survives restarts, container re-creation and image updates because it lives in bind mounts, never in a container filesystem.

**Second copy:** this NAS has one data volume, so `BACKUP_ROOT` on `/volume1` protects against mistakes and corruption but not against losing the volume. Copy `${BACKUP_ROOT}` to the USB disk (`rsync -a --delete-after` weekly from the NAS scheduler) and, if you can, keep a copy off-site (docs/BACKUP.md). Never put PGDATA on the USB disk.

## 3. Reaching the stack from phones
One origin, `PUBLIC_URL`, serves the API, Socket.IO and the web app; the reverse proxy (Caddy) routes by path and speaks **plain HTTP on port 8088**. PostgreSQL, Redis and MinIO (API + console) are never reachable from outside; `/health/ready` and Swagger are blocked at the proxy.

| Option | When | How |
|---|---|---|
| **A. Cloudflare Tunnel** (recommended for real use) | phones anywhere; the NAS already runs such tunnels | Cloudflare Zero Trust → Networks → Tunnels → *Create a tunnel* (Cloudflared) → name `yusmus` → copy the **token** → *Public hostname*: `yusmus.<your-domain>` → service **HTTP `caddy:8080`**. In `.env`: `CLOUDFLARE_TUNNEL_TOKEN=…`, `PUBLIC_URL=https://yusmus.<your-domain>`; start with `docker compose --profile tunnel up -d`. Outbound only: no router settings, works behind CGNAT. **Trade-off:** Cloudflare terminates TLS and can technically see the traffic (D-002/D-025) — the owner's decision. |
| **B. Home Wi-Fi / Tailscale** (first tests, no domain) | phones on the home network, or with the Tailscale app | `HTTP_BIND=0.0.0.0`, `PUBLIC_URL=http://192.168.1.105:8088` (or the Tailscale IP). Plain HTTP: Android needs cleartext allowed for that host (debug builds do); use only on trusted networks. |
| **C. Public IP + own TLS** | only if the ISP gives a real public IPv4 and 80/443 could be freed | Not possible here without moving the NAS's own ports; would need a TLS proxy in front (out of scope). |

The Telegram bot uses long polling: it needs **no inbound port** and works in every option.

Firewall: keep the NAS admin UI (UGOS) off the internet; SSH by key only. API rate limiting and login lockout are built in (SECURITY in ARCHITECTURE.md §5). Behind the tunnel Caddy takes the real client IP from `Cf-Connecting-Ip`.

## 4. Updates
```sh
git pull && docker compose up -d --build     # `migrate` runs prisma migrate deploy before the API starts
sh infra/scripts/verify-stack.sh
```
Take an on-demand backup first: `docker compose run --rm backup /opt/backup/pg-dump.sh`. Rolling back code = checkout the previous tag and rebuild; a bad migration is undone by restoring the dump (DISASTER-RECOVERY.md §3).

## 5. Sizing / safety
The NAS has plenty of RAM; the defaults in `.env` (`*_MEM_LIMIT`, `API_CPUS`, …) are deliberately small so we stay a good neighbour. With 62 GB free you may raise `POSTGRES_MEM_LIMIT` and `shared_buffers` in `infra/postgres/postgresql.conf`. Logs rotate (10 MB × 5). MinIO has a hard per-bucket quota (`MINIO_BUCKET_QUOTA_GB`) so it can never silently fill the NAS; watch free space on `DATA_ROOT` and `BACKUP_ROOT`. Docker's data root is on the HDD volume: expect PostgreSQL to be fast enough for this workload thanks to the SSD cache, but do not run heavy image builds during working hours.

## 6. Where the admin tools are
- MinIO console: `http://127.0.0.1:9001` **on the NAS only** (SSH tunnel: `ssh -L 9001:127.0.0.1:9001 nas`).
- Logs: `docker compose logs -f api worker` (JSON lines with `requestId`).
- Health: `curl http://127.0.0.1:8088/health/live` on the NAS (or `https://<PUBLIC_URL>/health/live` through the tunnel), `docker compose exec api node -e "fetch('http://127.0.0.1:3000/health/ready')…"`.

## 7. Owner checklist
1. **Telegram bot** — ✅ `@diamora1_bot` exists and connects (long polling verified). Before real workers: `/revoke` the token in @BotFather (it was pasted into a chat), put the new one in `.env`. Also `/setprivacy` is irrelevant (private chats only); set the bot name/photo/description in @BotFather.
2. **Yandex MapKit key** (needed from M4):
   1. Open <https://developer.tech.yandex.ru/services/> and sign in with a Yandex account (create one if needed).
   2. Press **Подключить API** (Connect APIs) and choose **MapKit Mobile SDK**.
   3. Fill in the project form (name *Yusmus*, your contact), pick the free licence (up to 25 000 monthly users) and press *Continue*.
   4. The key appears under **API Interfaces → MapKit Mobile SDK**. Wait ≈15 minutes for activation.
   5. Give it to the developer (or build the app with `--dart-define=YANDEX_MAPKIT_KEY=<key>`). Do not commit it to Git.
3. **Internet access** — decide between A (Cloudflare Tunnel) and B (home network / Tailscale) in §3.
4. **Rates** — ✅ 30 000 UZS per 9 m kit, editable in the ADMIN app; a partly accepted kit is paid pro rata (D-024, D-027).
5. **Passwords** — change the NAS password that was shared in a chat; prefer a dedicated SSH key/user for deployments.
