# Yusmus — home production on our own NAS

Replaces the notebook with a mobile-first system: **Telegram registration → SUPER_ADMIN/ADMIN/MANAGER app + WORKER app (Flutter) + a web control panel (Next.js) → NestJS on the NAS**, realtime, QR, Yandex Maps, cash-only payments, profit. All data lives on the NAS (PostgreSQL, MinIO, Redis); Telegram and Yandex are transport/tiles only.

Docs: [ARCHITECTURE](docs/ARCHITECTURE.md) · [DECISIONS](docs/DECISIONS.md) · [RBAC](docs/RBAC.md) · [CATALOG](docs/CATALOG.md) · [LIVE-LOCATION](docs/LIVE-LOCATION.md) · [BUSINESS-RULES](docs/BUSINESS-RULES.md) · [DATABASE](docs/DATABASE.md) · [API](docs/API.md) · [REALTIME](docs/REALTIME.md) · [TELEGRAM-BOT](docs/TELEGRAM-BOT.md) · [YANDEX-MAPS](docs/YANDEX-MAPS.md) · [QR](docs/QR.md) · [FINANCE](docs/FINANCE.md) · [NAS-DEPLOYMENT](docs/NAS-DEPLOYMENT.md) · [BACKUP](docs/BACKUP.md) · [DISASTER-RECOVERY](docs/DISASTER-RECOVERY.md) · [MVP-ROADMAP](docs/MVP-ROADMAP.md)

## Roles (D-028)
`SUPER_ADMIN` (full system control) > `ADMIN` (business operations, some settings need an explicit grant) > `MANAGER` (only their own assigned workers) > `WORKER` (only herself; catalog is public). See [RBAC.md](docs/RBAC.md).

## Develop (no Docker needed)
```sh
pnpm install
pnpm dev:db                                   # real PostgreSQL 17 on :54329 (data in .dev-data/) — keep running
cp .env.example .env                          # then set DATABASE_URL, JWT_ACCESS_SECRET, FILE_SIGNING_SECRET, STORAGE_DRIVER=memory
pnpm db:migrate:deploy                        # schema + integrity guards
pnpm --filter @yusmus/api build
pnpm --filter @yusmus/api cli:bootstrap -- --name "Owner" --phone "+998901234567"   # SUPER_ADMIN account (password printed once)
pnpm --filter @yusmus/api start               # API + Socket.IO on :3000  (Swagger: /docs)
pnpm --filter @yusmus/api dev:worker          # Telegram bot + outbox (needs TELEGRAM_BOT_TOKEN)
cd apps/mobile && flutter run --dart-define=API_URL=http://10.0.2.2:3000 --dart-define=YANDEX_MAPKIT_KEY=...
```
Existing deployment that predates SUPER_ADMIN? `pnpm --filter @yusmus/api cli:promote-owner -- --phone "+998..." --confirm-phone "+998..."` promotes an existing ADMIN/MANAGER once, explicitly (never assigns SUPER_ADMIN silently).

### Web control panel (SUPER_ADMIN / ADMIN / MANAGER)
```sh
CORS_ORIGINS=http://localhost:3010 pnpm --filter @yusmus/api start    # dev only: the panel and the API are different origins locally
pnpm --filter @yusmus/web dev                                        # :3010, talks to NEXT_PUBLIC_API_URL (default http://localhost:3000)
```
In production the panel and the API share one origin (Caddy path-routes `/v1/*` to the API, D-025), so CORS is a non-issue there.

## Test
```sh
pnpm --filter @yusmus/shared test             # domain: registration state machine, status machines, money, QR, permissions
pnpm --filter @yusmus/api test                # 78 integration tests on a REAL PostgreSQL (RBAC, catalog, location, presence, dashboard, …)
cd apps/mobile && flutter test                # models, Drift repository, app flows, location permission gate, catalog, team
pnpm --filter @yusmus/web build && pnpm --filter @yusmus/web typecheck
pnpm infra:lint                               # NAS guardrails: nothing dangerous published, pinned images, hardened containers
```
Client ↔ live API smoke test: see the header of `apps/mobile/test/integration/api_smoke_test.dart`.

## Production
See [NAS-DEPLOYMENT](docs/NAS-DEPLOYMENT.md): `sh infra/scripts/deploy-nas.sh <user>@<nas>` (uploads + builds + starts + `verify-stack.sh` in one command) or the manual steps.
