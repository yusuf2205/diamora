# RBAC — roles, permissions, manager scope (D-028)

## Roles

| Role | Rank | Signs in with |
|---|---|---|
| `SUPER_ADMIN` | 4 | phone + password |
| `ADMIN` | 3 | phone + password |
| `MANAGER` | 2 | phone + password |
| `WORKER` | 1 | phone + one-time Telegram code |

**Rank rule** (`apps/api/src/users/users.service.ts`): a user may create/update/deactivate/reassign the role or permissions of another user only if that user's rank is **strictly lower** than their own. `SUPER_ADMIN` may manage anyone. **Nobody may act on themselves** through these routes — not even `SUPER_ADMIN` — so a role/status/permission change is always someone else's decision, on the record (audit). There is always at least one active `SUPER_ADMIN` (`assertNotLastSuperAdmin`); in practice this can only be threatened by a self-action, which is already blocked, so it is a defence-in-depth check.

`WORKER` accounts are never created through `/v1/users` — they only exist through the Telegram registration (`RegistrationService`); `changeRole` refuses to turn a worker into staff.

## Permissions

`SUPER_ADMIN` always holds every permission. `ADMIN` and `MANAGER` get a documented **default** set and can be given more (or have defaults taken away) one at a time — never `ROLE_ASSIGN` or `PERMISSION_MANAGE`, which exist only for `SUPER_ADMIN`. `WORKER` has none; her own routes are gated by `@Roles('WORKER')` directly, not by a permission.

All of this lives in one place, `packages/shared/src/permissions.ts`, imported by both the API (authorization) and the realtime layer (room membership) so they can never disagree.

| Permission | ADMIN default | MANAGER default | Grantable to ADMIN | Grantable to MANAGER |
|---|---|---|---|---|
| `USER_VIEW_ALL` | ✅ | – | – | – |
| `USER_CREATE` / `USER_UPDATE` / `USER_DEACTIVATE` | – | – | ✅ | – |
| `ROLE_ASSIGN` / `PERMISSION_MANAGE` | – | – | never (SUPER_ADMIN only) | never |
| `WORKER_VIEW_ALL` / `WORKER_APPROVE` / `WORKER_UPDATE` | ✅ | – | ✅ | – |
| `WORKER_VIEW_ASSIGNED` | – | ✅ | – | – |
| `WORKER_ASSIGN_MANAGER` | – | – | ✅ | – |
| `COLLATERAL_VIEW` / `COLLATERAL_MANAGE` | ✅ | – | ✅ | ✅ |
| `ASSIGNMENT_VIEW_ALL` / `ASSIGNMENT_CREATE` / `ASSIGNMENT_ACCEPT` | ✅ | – | ✅ | `ASSIGNMENT_CREATE`/`ASSIGNMENT_ACCEPT` ✅ |
| `ASSIGNMENT_VIEW_ASSIGNED` | – | ✅ | – | – |
| `FINANCE_VIEW_ALL` / `CASH_PAYOUT` / `PROFIT_VIEW` | ✅ | – | ✅ | `CASH_PAYOUT` ✅ |
| `FINANCE_VIEW_ASSIGNED` | – | ✅ | – | – |
| `CATALOG_VIEW` / `CATALOG_MANAGE` | ✅ | – | ✅ | `CATALOG_VIEW` ✅ |
| `INVENTORY_VIEW` / `INVENTORY_MANAGE` | ✅ | – | ✅ | `INVENTORY_VIEW` ✅ |
| `MAP_VIEW_ALL` | ✅ | – | ✅ | – |
| `MAP_VIEW_ASSIGNED` | – | ✅ | – | – |
| `LIVE_LOCATION_VIEW_ALL` | ✅ | – | ✅ | – |
| `LIVE_LOCATION_VIEW_ASSIGNED` | – | ✅ | – | – |
| `PAY_RATE_MANAGE` | – | – | ✅ (§39: "если permission разрешает") | – |
| `SETTINGS_MANAGE` / `AUDIT_VIEW` | – | – | ✅ | – |

Server routes declare either `@Roles(...)` (exact role match, used for `WORKER`'s own routes and login) or `@Perm(...)` (any of the listed permissions; `RolesGuard` denies by default if a route has neither, nor `@Public`/`@Authenticated` — enforced by a test that scans every controller method).

## Manager scope — server-side, always

A `MANAGER` never receives another manager's data, from any endpoint or any realtime event, no matter what the client asks for. This is implemented once, in `scopeFor()`:

```ts
scopeFor(permissions, 'WORKER' | 'COLLATERAL' | 'ASSIGNMENT' | 'FINANCE' | 'LOCATION' | 'MAP')
  -> 'all'      // has the _ALL permission for this category
  -> 'assigned' // has the _ASSIGNED permission: Prisma where assignedManagerId = viewer.id
  -> 'none'     // neither: 403 (or, if the specific row exists but is out of scope: 404)
```

REST handlers call `workerScope()`/`assertWorkerInScope()` (`apps/api/src/common/scope.ts`) with the same category. A worker outside a manager's scope answers **404**, not 403 — existence is not revealed either.

Realtime uses the identical function: `roomsForUser()` puts a manager only in `cat:<category>:mgr:<their own id>` rooms (never another manager's), and `roomsForEvent()` addresses an event to the worker's *current* `assignedManagerId` (and, for a manager reassignment, also to the *previous* manager, so their list drops the worker immediately). See [REALTIME.md](REALTIME.md).

## Assigning a manager

`POST /v1/workers/:id/manager { managerId }` — `WORKER_ASSIGN_MANAGER` (SUPER_ADMIN by default; ADMIN needs the grant, MANAGER never). The target must be an existing, active `MANAGER` (409 otherwise). Publishes `worker.manager_changed`.

## Bootstrapping SUPER_ADMIN (D-032)

- **Fresh database:** `node dist/cli/bootstrap.js --name "..." --phone "+998..." [--role ADMIN|MANAGER]` defaults to `SUPER_ADMIN` and refuses to create a second one (the very first account is the unambiguous owner).
- **Existing database** (had only `ADMIN`/`WORKER` before D-028): `node dist/cli/bootstrap.js` on a database that already has a `SUPER_ADMIN` fails on purpose. Use `node dist/cli/promote-owner.js --phone "+998..." --confirm-phone "+998..."` instead: it only promotes an *existing* `ADMIN`/`MANAGER`, requires the phone typed twice identically, never creates an account, drops that user's per-permission overrides (meaningless once they have everything) and revokes their sessions (they sign in again with the new role).

## Testing

`apps/api/test/rbac.spec.ts` (real PostgreSQL): default permission sets per role, the rank rule (who can create whom), self-action always blocked, deactivation kills live sessions immediately, manager assignment rules, manager isolation across list/detail/collateral (403 without the permission at all, 404 for another manager's worker with the permission), realtime isolation (`worker.manager_changed` reaches only the right manager), a `WORKER` never reaching a staff route. `apps/mobile/test/team_test.dart` covers the Flutter "Команда" screen's permission gating.
