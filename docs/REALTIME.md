# Realtime

**Rule:** `Client → API → validation → PostgreSQL transaction → COMMIT → event bus → WebSocket`. Never emit before COMMIT; never trust client state.

## Transport
- Socket.IO on the API (`wss://<domain>/socket.io`), handshake `auth: { token: <access JWT> }`. Invalid/revoked session → disconnect; a role/permission change disconnects the user's sockets too (they reconnect with fresh rooms).
- **Rooms are computed from the connecting user's EFFECTIVE permissions** (`roomsForUser`, `packages/shared/src/events.ts`), not from their role name — this is the one place REST and WebSocket authorization share code (see [RBAC.md](RBAC.md)):
  - every staff user joins `staff` and one `perm:<PERMISSION>` room per permission they hold;
  - for each worker-scoped category (`WORKER`, `COLLATERAL`, `ASSIGNMENT`, `FINANCE`, `LOCATION`, `MAP`) a staff user additionally joins `cat:<category>:all` (has the `_ALL` permission) or `cat:<category>:mgr:<their own id>` (has only `_ASSIGNED` — a MANAGER's own room, nobody else's);
  - a WORKER joins `worker:<workerProfileId>` and the broadcast room `workers`; nothing else.
- **Events are routed by `roomsForEvent(type, data)`**, using the same category + the event's `managerId`/`previousManagerId` field — the server decides who receives what; a client is never sent data it may not see "with the UI just hiding it".
- Bus: Redis pub/sub channel `yusmus:events` (so the bot process and future API replicas reach all sockets). Without `REDIS_URL` an in-process emitter is used (tests).
- No replay: after reconnect the client refetches its screen data. Events are hints ("something changed"), payloads stay small and never contain full addresses, collateral details or bank-like data beyond what that audience may see.
- **Presence** (D-031): the app sends `presence:ping` periodically; the gateway keeps `User.lastSeenAt` fresh and a live in-memory online/offline flag ([LIVE-LOCATION.md](LIVE-LOCATION.md#presence--separate-from-gps-d-031)).

## Envelope
```json
{ "id": "uuid", "type": "assignment.status_changed", "occurredAt": "2026-09-21T10:00:00.000Z", "data": { } }
```

## Event contracts (`packages/shared/src/events.ts`)

| Event | data | Audience |
|---|---|---|
| `user.created` / `.updated` / `.role_changed` / `.permission_changed` | userId, … | `USER_VIEW_ALL`, (+ the user herself for the last three) |
| `user.presence_changed` | userId, role, online, lastSeenAt, managerId | `USER_VIEW_ALL` + her manager |
| `user.location.updated` | userId, role, latitude, longitude, recordedAt, managerId, workerId? | `LIVE_LOCATION_VIEW_ALL` + her manager + herself |
| `worker.created` | workerId, code, fullName, status | staff with `WORKER_VIEW_ALL` |
| `worker.approved` / `worker.rejected` | workerId, managerId | staff scoped to this worker, + the worker |
| `worker.manager_changed` | workerId, managerId, previousManagerId | staff with `WORKER_VIEW_ALL` + the new AND the previous manager |
| `worker.location.updated` | workerId, latitude, longitude, receivedAt, managerId | staff scoped to this worker (`LOCATION` category) |
| `collateral.created` / `collateral.updated` | collateralId, workerId, type, status, managerId | staff scoped to this worker (`COLLATERAL`), + the worker (updated) |
| `catalog.item.created` / `.updated` | itemId | staff with `CATALOG_VIEW` |
| `catalog.item.published` / `.hidden` / `.deleted` / `catalog.order.changed` | itemId (or none) | staff with `CATALOG_VIEW` + **every connected worker** |
| `company_contact.changed` | phone, telegramUsername, telegramUrl | every staff user + every worker |
| `job_request.created` / `job_request.decided` | requestId, workerId, kitCount / status, managerId | staff scoped to this worker / the worker |
| `assignment.created` / `.updated` / `.status_changed` | assignmentId, workerId, managerId, … | staff scoped to this worker (`ASSIGNMENT`), + the worker |
| `work.progress_updated` / `work.ready_for_pickup` | assignmentId, workerId, managerId, … | staff scoped to this worker |
| `delivery.created` / `delivery.completed` | deliveryId, workerId, type, assignmentId, managerId | staff scoped to this worker, + the worker |
| `quality.completed` | assignmentId, workerId, result, acceptedMeters, managerId | staff scoped to this worker, + the worker |
| `pay_rate.changed` | ratePerKit, previousRatePerKit, changedAt | every staff user + **every worker** |
| `earning.created` / `cash_payment.created` / `worker.balance_updated` | workerId, …, managerId | staff scoped to this worker (`FINANCE`), + the worker |
| `stock.updated` | materialId, quantity, low | staff with `INVENTORY_VIEW` |
| `sale.created` / `profit.updated` | saleId / period | staff with `PROFIT_VIEW` |

Implemented: `user.*`, `worker.*`, `collateral.*`, `catalog.*`, `company_contact.changed`, `pay_rate.changed`. The rest are added with their milestone; the contract file (`EVENT_ROUTES`) already lists all of them with their final routing.
