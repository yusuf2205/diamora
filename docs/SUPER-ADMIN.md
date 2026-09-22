# SUPER_ADMIN — mobile + web (§29-30)

`SUPER_ADMIN` has every permission (`packages/shared/src/permissions.ts`) and is not tied to a computer: everything
below works from the Flutter app; the web control panel (Next.js) mirrors the same API for a desk/laptop workflow.
Both talk to the same NAS API — no separate backend, no separate rules.

## What exists today (built and tested)

| Area | Flutter | Web | API |
|---|---|---|---|
| Sign in (phone + password, any staff role) | ✅ | ✅ | `POST /v1/auth/admin/login` |
| Dashboard (workers, users, catalog, work in progress, finance so far, low stock) | — (Profile shows individual tiles instead) | ✅ `/dashboard` | `GET /v1/dashboard` |
| Workers: list, detail, approve/reject, collateral | ✅ | ✅ (list) | existing M1 routes, now scoped by permission |
| Users: create, view, activate/deactivate, roles, permissions | ✅ "Команда" | ✅ `/team` | `/v1/users`, `/v1/permissions` |
| Managers: per-manager numbers | ✅ | ✅ `/managers` | `/v1/managers` |
| Assign a worker to a manager | ✅ (worker detail) | — | `POST /v1/workers/:id/manager` |
| Catalog "Наши работы": create, photos/video, publish/hide, variants | ✅ | ✅ (create, publish/hide; photo upload is mobile-only so far) | `/v1/admin/catalog/*` |
| Global 9 m pay rate + history | ✅ | ✅ | `/v1/settings/pay-rate*` |
| Company contact (phone/Telegram shown to workers) | ✅ | ✅ | `/v1/settings/company-contact` |
| Live locations (list; a real map is M4) | ✅ "Геолокация команды" | — | `GET /v1/locations` |
| Presence (online/offline) | used inside the above lists | used inside the above lists | `GET /v1/presence` |
| Audit log | ✅ | ✅ | `GET /v1/audit` |

## Not built yet (by design — D-023, no mocks in critical flows)

Assignments, deliveries, pickup/acceptance, the Yandex map, QR resolution, materials/stock, sales, expenses and net
profit belong to milestones **M2–M6**, which have not started. Nothing in this session invents data or screens for
them; `GET /v1/dashboard`'s `finance.salesRevenue/expenses/netProfit` are explicit `null`, not a fabricated zero. See
[MVP-ROADMAP.md](MVP-ROADMAP.md) for the plan and the honest gap register.

## Getting there for the first time

1. `pnpm --filter @yusmus/api cli:bootstrap -- --name "..." --phone "+998..."` on a fresh database creates the first
   `SUPER_ADMIN` (see [RBAC.md](RBAC.md) for `promote-owner.js` on an existing one).
2. Sign in from either app with that phone/password.
3. Create `ADMIN`/`MANAGER` accounts from "Команда" (Flutter) or `/team` (web); assign workers to managers from a
   worker's detail screen.
