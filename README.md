# Yusmus — home production on our own NAS

Replaces the notebook with a mobile system: **Telegram registration → ADMIN app + WORKER app (Flutter) → NestJS on the NAS**, realtime, QR, Yandex Maps, cash-only payments, profit. All data lives on the NAS (PostgreSQL, MinIO, Redis); Telegram and Yandex are transport/tiles only.

Docs: [ARCHITECTURE](docs/ARCHITECTURE.md) · [DECISIONS](docs/DECISIONS.md) · [BUSINESS-RULES](docs/BUSINESS-RULES.md) · [DATABASE](docs/DATABASE.md) · [API](docs/API.md) · [REALTIME](docs/REALTIME.md) · [TELEGRAM-BOT](docs/TELEGRAM-BOT.md) · [YANDEX-MAPS](docs/YANDEX-MAPS.md) · [QR](docs/QR.md) · [FINANCE](docs/FINANCE.md) · [NAS-DEPLOYMENT](docs/NAS-DEPLOYMENT.md) · [BACKUP](docs/BACKUP.md) · [DISASTER-RECOVERY](docs/DISASTER-RECOVERY.md) · [MVP-ROADMAP](docs/MVP-ROADMAP.md)

## Develop (no Docker needed)
```sh
pnpm install
pnpm dev:db                                   # real PostgreSQL 17 on :54329 (data in .dev-data/) — keep running
cp .env.example .env                          # then set DATABASE_URL, JWT_ACCESS_SECRET, FILE_SIGNING_SECRET, STORAGE_DRIVER=memory
pnpm db:migrate:deploy                        # schema + integrity guards
pnpm --filter @yusmus/api build
pnpm --filter @yusmus/api cli:bootstrap -- --name "Owner" --phone "+998901234567"   # ADMIN account (password printed once)
pnpm --filter @yusmus/api start               # API + Socket.IO on :3000  (Swagger: /docs)
pnpm --filter @yusmus/api dev:worker          # Telegram bot + outbox (needs TELEGRAM_BOT_TOKEN)
cd apps/mobile && flutter run --dart-define=API_URL=http://10.0.2.2:3000
```

## Test
```sh
pnpm --filter @yusmus/shared test             # domain: registration state machine, status machines, money, QR
pnpm --filter @yusmus/api test                # 53 integration tests on a REAL PostgreSQL (migrations + DB guards included)
cd apps/mobile && flutter test                # models, Drift repository, app flows
pnpm infra:lint                               # NAS guardrails: nothing dangerous published, pinned images, hardened containers
```
Client ↔ live API smoke test: see the header of `apps/mobile/test/integration/api_smoke_test.dart`.

## Production
See [NAS-DEPLOYMENT](docs/NAS-DEPLOYMENT.md): `sh infra/scripts/nas-init.sh` → edit `.env` → `docker compose up -d --build` → `sh infra/scripts/verify-stack.sh`.
