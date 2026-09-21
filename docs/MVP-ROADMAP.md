# MVP roadmap

| Milestone | Scope | Status |
|---|---|---|
| **M0** Infrastructure | Docker stack (postgres, redis, minio, api, worker/bot, web, caddy, backup), NestJS + WebSocket + bot foundation, Prisma schema (38 tables) + DB guards, Flutter & Next.js foundations, health, backups | ✅ done — see "Verification" |
| **M1** Registration | Telegram registration (phone, GPS, collateral), ADMIN approval/rejection, worker profile, realtime, worker login by Telegram code, collateral receive/return, audit | ✅ done — see "Verification" |
| M2 | Products, colours, materials, 9 m kit templates, stock movements (issue/receipt/adjust), QR | next |
| M3 | Assignments 9/18/27 m, delivery, Worker app (home, work, progress), job requests | – |
| M4 | Ready for pickup, **Yandex map** + filters, pickup, acceptance | – |
| M5 | Earnings **per 9 m kit** (D-024), cash payout, ledger, worker "К получению" | – |
| M6 | Sales, expenses, net-profit dashboard | – |
| M7 | Visual improvements, gamification, achievements, portfolio | – |

The **end-to-end MVP test** (brief §60, 33 steps) is the acceptance test of M6.

## Verification (what was actually run)
| Area | Evidence |
|---|---|
| Domain (`packages/shared`) | 15 tests (incl. the global 9 m price, D-027): Telegram registration state machine (money/item paths, foreign contact, edits, photo limits, immutability of state), assignment/collateral machines, money rounding, QR format |
| Database | migrations applied to a real PostgreSQL 17 (UTF-8 + ICU ru-RU, as in production); `prisma migrate dev` drift check = empty; guards tested: append-only triggers (ledger, collateral history/photos, stock movements, status history, audit), CHECKs (stock ≥ 0, accepted + defective ≤ delivered, kit count, amounts), unique identities, self-check views |
| API (`apps/api`) | 53 integration tests (8 suites; 9 of them for the global 9 m price: ADMIN-only change, everyone reads it, history/audit, idempotent retry, 6 concurrent changes without a fork, realtime to ADMIN + every worker, append-only trigger) on real PostgreSQL, run twice in a row: registration via bot inputs (incl. 5 parallel album photos, restart-safe drafts, PHONE_TAKEN), approval/rejection, worker Telegram-code login (single use, attempt limit, no enumeration), collateral receive/return (row-lock race: exactly one wins), photos (real image validation, dedupe), Idempotency-Key, outbox (retry/back-off, SKIP LOCKED, wiping login codes), realtime over real Socket.IO (audience isolation, revoke → disconnect), deny-by-default route scan, tenant-free RBAC |
| Runtime | compiled API and worker started from a `pnpm deploy --prod` artifact (same layout as the Docker image): migrator entry (`migrate status`), `/health/live`, `/health/ready`, login over HTTP |
| Flutter | 18 tests (price screen: ADMIN edit + validation, worker card following a realtime change; models against real payloads, Drift repository with delta sync/filtering/wipe, app flows/redirects) + `flutter analyze` clean; **smoke test of the real client code against the live API**: login, session restore, Socket.IO, delta sync into Drift, detail, approve with Idempotency-Key and the `worker.approved` event arriving on the socket; and for the 9 m price: read, change 30 000 → 35 000, `pay_rate.changed` arriving on the socket, history, restore (DB afterwards: chain 30 000 → 35 000 → 30 000, 2 audit rows); DB side effects confirmed afterwards |
| Web | `next build` (Turbopack) succeeds, standalone `server.js` present |
| Infra | `pnpm infra:lint` passes and is mutation-tested (published DB port, unpinned image, API on egress network → all caught); backup scripts logic-tested with stubbed PG tools (rotation, checksums, verify, tamper detection) |

## Known gaps / debt register (honest list)
1. **Docker is not installed on the development machine**: `docker compose up` and the Dockerfiles were **not executed** — only statically linted and their build steps emulated natively (`pnpm deploy`, Prisma generate, running the artifact). The NAS *has* Docker 29 / Compose 5 (inspected read-only, D-025) but **nothing has been deployed to it yet**: the owner approved the deployment (2026-09-21) but the session's permission layer blocked writing to the shared NAS, so `infra/scripts/deploy-nas.sh` is ready and waits for a permitted run. First real run on the NAS: `sh infra/scripts/verify-stack.sh`. Untested until then: the Caddy `trusted_proxies`/`client_ip_headers` block, the read-only `cloudflared` container and its `ready` healthcheck, the pinned subnets.
2. **Backup scripts were tested with stubs** (no `pg_dump`/`psql` on this machine). The daily `verify.sh` job restores a real dump on the NAS every night and is the real test; do one manual drill (DISASTER-RECOVERY §3–§4) in the first week. MinIO init/mirror (`mc`) also runs for the first time on the NAS.
3. **Telegram bot ↔ real Telegram: connection verified, a live registration not yet.** With the owner's token (dev `.env`, git-ignored) the worker started, resolved `@diamora1_bot`, began long polling (no webhook set) and the outbox made a real `sendMessage` call (Telegram answered "chat not found" for a stale fake chat id from an earlier dev test — the retry/back-off path behaved as designed). Still open: a real person going through the whole registration dialogue (contact/GPS/photo messages as Telegram really sends them). The interface layer (`worker/telegram-bot.ts`) is thin and everything behind it is tested.
4. **Flutter is analyzed/tested on the desktop test runner only** — not run on a device/emulator. Yandex MapKit is not integrated yet (M4; the owner's key is received and stored in `.env`, but cannot be verified before the map screen exists).
5. MinIO upstream is archived (D-015) — plan migration to Garage/SeaweedFS in the improvements phase.
6. Not built yet by design: catalog/stock/assignments/finance/sales/QR endpoints (schema, state machines, event contracts and docs exist); Redis event bus is implemented but only exercised in-process in tests (Redis isn't available on this machine) — verified on the NAS by `verify-stack.sh` + a live registration reaching an open ADMIN app.
7. Web is a status page only (tables/reports arrive with M4–M6).
8. No ESLint yet (TypeScript strict + Flutter analyzer only).

## Working agreement
Each milestone ends with: schema + migration → backend → API → Flutter → validation → tests → docs → commit-ready. UI changes requested after visual review must not require backend changes unless the data itself changes.
