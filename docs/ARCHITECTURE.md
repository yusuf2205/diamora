# Architecture

**Simple first → working MVP → visual review → improvements.** Home business: `SUPER_ADMIN`/`ADMIN`/`MANAGER`/`WORKER` (D-028), Telegram, phones, one NAS.

## 1. Architecture Decision Summary (details: DECISIONS.md)

- **NAS-first, Docker Compose**, everything self-hosted; Telegram (transport) and Yandex MapKit (tiles) are the only external services and receive no business data beyond what the worker herself sends to Telegram.
- **NestJS = business logic**, PostgreSQL = source of truth, Redis = realtime bus, MinIO = files.
- **Telegram bot = thin interface** in a separate process (long polling), state in PostgreSQL.
- **Realtime** after COMMIT via Socket.IO + Redis pub/sub; rooms are computed from the same permission/scope model as REST ([RBAC.md](RBAC.md)), so a socket can never receive data its owner may not read.
- **Four ranked roles, fine-grained permissions on top** ([RBAC.md](RBAC.md)): `SUPER_ADMIN` has everything; `ADMIN`/`MANAGER` get documented defaults and can be granted more; a `MANAGER` is scoped server-side to her own assigned workers everywhere (REST and realtime).
- **Flutter** (Riverpod, GoRouter, Dio, Freezed, Drift) for every role (staff shell vs. worker shell), **Next.js** (client-rendered, same public API, token auth) as the SUPER_ADMIN/ADMIN/MANAGER web control panel ([SUPER-ADMIN.md](SUPER-ADMIN.md)).
- Money = BigInt UZS, immutable ledger, immutable histories (DB triggers), cash only.

## 2. Runtime view

```
 Worker phone                    Telegram                     ADMIN phone / Web
 (Telegram + Flutter)               │                          (Flutter / Next.js)
        │  HTTPS (JWT)              │ long polling                   │ HTTPS + WSS
        ▼                           ▼                                ▼
   ┌── Internet (Cloudflare Tunnel, opt-in) / home Wi-Fi ── Caddy :8088 (only published port, plain HTTP) ──┐
   │                                   │
   │ NAS (Docker)          edge network│                       internal `data` network
   │   ┌──────────┐   ┌──────────────┐ │  ┌───────────┐  ┌───────┐  ┌───────┐
   │   │   web    │   │     api      │◄┘  │ PostgreSQL│  │ Redis │  │ MinIO │
   │   │ Next.js  │   │ REST + WS    │───►│ (truth)   │  │ pub/  │  │ files │
   │   └──────────┘   │ business     │    └───────────┘  │ sub   │  └───────┘
   │                  └──────▲───────┘        ▲          └───▲───┘
   │                         │ Redis events   │              │
   │                  ┌──────┴───────┐        │              │
   │                  │   worker     │────────┘──────────────┘   egress network → Telegram Bot API
   │                  │ Telegram bot │  (same code, other entrypoint: bot + outbox sender + maintenance)
   │                  └──────────────┘        backup container → NAS backup volume
   └────────────────────────────────────────────────────────────────────────────────────┘
```

Critical write path (money, collateral, stock, issue, acceptance, payout):
`client → API → validation → PostgreSQL transaction → COMMIT → event bus → WebSocket`. Clients never decide truth.

## 3. Monorepo

```
apps/api       NestJS: REST, WebSocket gateway, Telegram bot + maintenance entrypoints (src/worker.ts), CLI
apps/web       Next.js (SUPER_ADMIN/ADMIN/MANAGER control panel: users, workers, managers, catalog, settings, audit)
apps/mobile    Flutter (every role; staff shell vs. worker shell, permission-gated tabs, background location)
packages/shared    roles, permissions, enums, state machines, registration flow, validation (zod), realtime contracts, money/metres
packages/database  Prisma schema, migrations (incl. DB guards), generated client
packages/config    shared tsconfig
docs/          this documentation
infra/         Caddy, PostgreSQL config, MinIO init, backup scripts, NAS scripts, Dockerfiles
docker-compose.yml   production stack (postgres, redis, minio, api, worker, web, caddy, backup; optional cloudflared)
```

## 4. API modules (NestJS)

`config` · `common` (context, errors, zod pipe, idempotency, `scope.ts` manager scoping) · `prisma` · `redis` · `storage`+`files` · `audit` · `events` (bus + Socket.IO gateway) · `presence` · `stats` (dashboard) · `auth` · `notifications` (outbox) · `registration` (bot logic) · `users` (roles/permissions/managers) · `workers` · `collateral` · `catalog` · `location` · `settings` (pay-rate, company-contact) · later: `stock`, `assignments`, `deliveries`, `quality`, `finance`, `sales`, `qr`, `map`.

## 5. Security in one paragraph

HTTPS only; JWT access (15 min) + rotating refresh with reuse detection and per-device sessions; login lockout; role guards **deny by default** (a test enumerates all routes); Idempotency-Key for retried mutations; signed short-lived file URLs; DB and Redis never published; secrets only in `.env` on the NAS; audit log for money/collateral/stock/acceptance/profile changes.

## 6. Where to change what (UI freedom)

Backend contracts are stable JSON DTOs (`docs/API.md`). Flutter screens depend on providers/repositories, never on Dio/Drift directly; theme tokens live in `core/theme`. Redesigning screens does not touch backend, repositories or business rules.
