# MVP roadmap

| Milestone | Scope | Status |
|---|---|---|
| **M0** Infrastructure | Docker stack (postgres, redis, minio, api, worker/bot, web, caddy, backup), NestJS + WebSocket + bot foundation, Prisma schema + DB guards, Flutter & Next.js foundations, health, backups | ✅ done — see "Verification" |
| **M1** Registration | Telegram registration (phone, GPS, collateral), ADMIN approval/rejection, worker profile, realtime, worker login by Telegram code, collateral receive/return, audit | ✅ done — see "Verification" |
| **RBAC/Catalog/Location upgrade** (owner request, 2026-09-22, ahead of M2) | Four ranked roles + fine-grained permissions ([RBAC.md](RBAC.md)), manager-worker assignment and isolation, catalog "Наши работы" ([CATALOG.md](CATALOG.md)), background live location + presence ([LIVE-LOCATION.md](LIVE-LOCATION.md)), SUPER_ADMIN web control panel ([SUPER-ADMIN.md](SUPER-ADMIN.md)), audit/dashboard | ✅ done — see "Verification" |
| M2 | Materials, 9 m kit templates, stock movements (issue/receipt/adjust), QR (the catalog's product/colour/variant tables already exist, built above) | next |
| M3 | Assignments 9/18/27 m, delivery, Worker app (work, progress), job requests | – |
| M4 | Ready for pickup, **Yandex map** (using the live-location data already built) + filters, pickup, acceptance | – |
| M5 | Earnings **per 9 m kit** (D-024), cash payout, ledger, worker "К получению" | – |
| M6 | Sales, expenses, net-profit dashboard | – |
| M7 | Visual improvements, gamification, achievements, portfolio | – |

The **end-to-end MVP test** (brief §60, 33 steps) is the acceptance test of M6.

## Verification (what was actually run)
| Area | Evidence |
|---|---|
| Domain (`packages/shared`) | 23 tests: Telegram registration state machine (money/item paths, foreign contact, edits, photo limits, immutability of state), assignment/collateral machines, money rounding, QR format, the global 9 m price, and RBAC (`ROLE_RANK`, `effectivePermissions`, `scopeFor`, `roomsForUser`/`roomsForEvent` — a manager never lands in an "all" room, a manager reassignment event reaches both the new and the previous manager and nobody else) |
| Database | migrations applied to a real PostgreSQL 17 (UTF-8 + ICU ru-RU, as in production); `prisma migrate diff` drift check = empty; guards tested: append-only triggers (ledger, collateral history/photos, stock movements, status history, audit, pay-rate history), CHECKs (stock ≥ 0, accepted + defective ≤ delivered, kit count, amounts, GPS range on both `worker_profiles` and `user_live_locations`), a DB trigger rejecting a non-MANAGER `assignedManagerId`, unique identities, self-check views |
| API (`apps/api`) | **78 integration tests, 12 suites**, on real PostgreSQL, run repeatedly (stable): registration via bot inputs, approval/rejection, worker Telegram-code login, collateral receive/return, Idempotency-Key, outbox, realtime over real Socket.IO, deny-by-default route scan (now recognising `@Perm` too), the global 9 m price (9 tests), **RBAC** (`rbac.spec.ts`, 10 tests: default permissions per role, the rank rule, self-action always blocked, deactivation kills live sessions immediately, manager-assignment rules, manager isolation on list/detail/collateral incl. 404-not-403, realtime isolation), **catalog** (`catalog.spec.ts`, 8 tests: publish-needs-a-photo, no price anywhere, media/variants/video/dedupe/reorder, delete-blocked-when-used, permission boundaries, realtime to workers+staff), **live location** (`location.spec.ts`, 5 tests: self-only reporting, coordinate validation, manager/`_ALL` scope, staleness, realtime routing), **dashboard** (`dashboard.spec.ts`, 3 tests: real counts, permission boundary, honest `null` for unbuilt M6 finance) |
| Runtime | compiled API and worker started from a `pnpm deploy --prod` artifact (same layout as the Docker image): migrator entry (`migrate status`), `/health/live`, `/health/ready`, login over HTTP |
| Flutter | **31 tests** (2 env-gated live-API tests skipped without credentials): price screen, models, Drift repository, app flows/redirects, **location permission gate** (`location_gate_test.dart`, 6 tests: every missing-permission screen shows the right text and calls the right system action, never a fake "I turned it on"), **catalog** (`catalog_test.dart`, 5 tests: default screen, empty state, detail with/without configured contact — no price anywhere on either), **team** (`team_test.dart`, 2 tests: permission-gated "insufficient rights", create+deactivate flow, never a switch for yourself) + `flutter analyze` clean; **smoke test of the real client code against the live API** (2 tests, env-gated): login/session/realtime/approve, and the 9 m price end to end |
| Web | `next build` (Turbopack) succeeds for every route (`/login`, `/dashboard`, `/workers`, `/catalog`, `/team`, `/managers`, `/settings`, `/audit`); `tsc --noEmit` clean; a built server was started against the live dev API and `/login`, `/dashboard`, `/api/health` were checked over HTTP — **no automated web tests exist yet** (honest gap, below) and no browser click-through was performed (no browser-automation tool available in this session) |
| Infra | `pnpm infra:lint` passes and is mutation-tested (published DB port, unpinned image, API on egress network, unpublished/mispublished Caddy port, unpinned subnet, non-opt-in tunnel, hard-coded tunnel token → all caught); backup scripts logic-tested with stubbed PG tools |

## Known gaps / debt register (honest list)
1. **Docker is not installed on the development machine**: `docker compose up` and the Dockerfiles were **not executed** — only statically linted and their build steps emulated natively. The NAS has Docker 29 / Compose 5 (inspected read-only, D-025) but **nothing has been deployed to it**: `infra/scripts/deploy-nas.sh` is ready. First real run: `sh infra/scripts/verify-stack.sh`.
2. **Backup scripts were tested with stubs** (no `pg_dump`/`psql` on this machine). The daily `verify.sh` job on the NAS is the real test; do one manual drill (DISASTER-RECOVERY §3–§4) in the first week.
3. **Telegram bot ↔ real Telegram: connection verified (resolves `@diamora1_bot`, long polling, a real outbox `sendMessage` call), a live registration by a real person not yet.**
4. **Flutter is analyzed/tested on the desktop test runner only** — not run on a device/emulator. Yandex MapKit is not integrated yet (M4; the owner's key is received and stored in `.env`, but cannot be verified before the map screen exists). Photo/video upload for the catalog exists in the mobile app only, not the web panel yet.
5. **The web control panel has no automated tests** (no Jest/Playwright wired for `apps/web` yet) — verified by `next build`/`tsc --noEmit` and one manual HTTP smoke check of three routes against a live API; no interactive click-through. This is the most honest gap in this round: real, but thinner verification than everywhere else in the repo.
6. MinIO upstream is archived (D-015) — plan migration to Garage/SeaweedFS in the improvements phase.
7. Not built yet by design: stock/assignments/finance/sales/QR endpoints and the Yandex map screen (schema, state machines, event contracts and docs exist for most); Redis event bus is implemented but only exercised in-process in tests (Redis isn't available on this machine).
8. No ESLint yet (TypeScript strict + Flutter analyzer only).
9. `promote-owner.js` and the first `bootstrap.js --role SUPER_ADMIN` run are logic-tested indirectly (the RBAC suite creates `SUPER_ADMIN` users directly via the same code path as `bootstrap.js`) but the CLI scripts themselves were not spawned as processes in this session.

## Working agreement
Each milestone ends with: schema + migration → backend → API → Flutter → validation → tests → docs → commit-ready. UI changes requested after visual review must not require backend changes unless the data itself changes.
