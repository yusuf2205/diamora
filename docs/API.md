# REST API (`/v1`, JSON, Swagger at `/docs` in dev)

Auth: `Authorization: Bearer <access JWT>`. Errors: `{ "error": { "code", "message", "requestId", "details?" } }`. Mutations accept `Idempotency-Key`. Lists use keyset pagination (`limit`, `cursor`, `updatedSince`).
Legend: **A** = any staff role with the permission shown (SUPER_ADMIN always qualifies), **W** = WORKER, ✅ = implemented. Server-side scope (a MANAGER sees only her own workers) is not repeated per row — see [RBAC.md](RBAC.md).

| Area | Endpoints |
|---|---|
| Auth ✅ | `POST /auth/admin/login` (phone+password, any staff role) · `POST /auth/worker/code` (phone → bot sends code) · `POST /auth/worker/login` (phone+code) · `POST /auth/refresh` · `POST /auth/logout` · `POST /auth/logout-all` · `GET /auth/me` (incl. `permissions`) · `GET /auth/sessions` · `DELETE /auth/sessions/:id` |
| Users & roles ✅ | `PERMISSION_MANAGE`/`USER_VIEW_ALL`: `GET /permissions` (catalog of every permission + role defaults) · `USER_VIEW_ALL`: `GET /users?role&status&q` · `GET /users/:id` · `USER_CREATE`: `POST /users` · `USER_UPDATE`: `PATCH /users/:id` · `POST /users/:id/reset-password` · `USER_DEACTIVATE`: `POST /users/:id/status` · `ROLE_ASSIGN`: `PUT /users/:id/role` · `PERMISSION_MANAGE`: `PUT /users/:id/permissions` |
| Managers ✅ | `USER_VIEW_ALL` (or own): `GET /managers` · `GET /managers/:id` (per-manager stats + her workers) |
| Workers ✅ | `WORKER_VIEW_ALL`/`_ASSIGNED`: `GET /workers?status&q` · `GET /workers/:id` · `WORKER_UPDATE`: `PATCH /workers/:id` · `WORKER_APPROVE`: `POST /workers/:id/approve` · `POST /workers/:id/reject` · `WORKER_ASSIGN_MANAGER`: `POST /workers/:id/manager` · W: `GET /workers/me` |
| Collateral ✅ | `WORKER_VIEW_*`+`COLLATERAL_VIEW`: `GET /collaterals?workerId&status` · `GET /collaterals/:id` · `COLLATERAL_MANAGE`: `POST /collaterals/:id/receive` · `POST /collaterals/:id/return` · `POST /collaterals/:id/photos` · W: `GET /workers/me/collateral` |
| Catalog "Наши работы" ✅ | W: `GET /catalog` (published only, no price) · `GET /catalog/:id` · `CATALOG_VIEW`/`_MANAGE`: `GET /admin/catalog?status` · `GET /admin/catalog/:id` · `CATALOG_MANAGE`: `POST /admin/catalog` · `PATCH .../:id` · `POST .../:id/publish`/`hide` · `DELETE .../:id` · `POST/PATCH .../:id/variants[/:id]` · `POST .../:id/media` (multipart) · `POST .../media/:id/main` · `DELETE .../media/:id` · `PUT .../order`, `.../:id/media/order` — see [CATALOG.md](CATALOG.md) |
| Live location & presence ✅ | any signed-in role: `POST /location` (self-report) · `LIVE_LOCATION_VIEW_ALL`/`_ASSIGNED`: `GET /locations` · `USER_VIEW_ALL`/`WORKER_VIEW_ASSIGNED`: `GET /presence` — see [LIVE-LOCATION.md](LIVE-LOCATION.md) |
| Pay rate ✅ | any signed-in role: `GET /settings/pay-rate` → `{ ratePerKit, kitMeters: 9, updatedAt }` · `PAY_RATE_MANAGE`: `PUT /settings/pay-rate` `{ ratePerKit, note? }` (one global price per 9 m kit, applies to everyone; same value = `changed:false`) · `GET /settings/pay-rate/history` |
| Company contact ✅ | any signed-in role: `GET /settings/company-contact` · `SETTINGS_MANAGE`: `PUT /settings/company-contact` |
| Dashboard ✅ | `WORKER_VIEW_ALL`/`FINANCE_VIEW_ALL`/`PROFIT_VIEW`: `GET /dashboard` (workers, users, catalog, work in progress, finance so far — sales/expenses/profit are `null` until M6, never fabricated) |
| Realtime ✅ | Socket.IO `wss://…/socket.io` ([REALTIME.md](REALTIME.md)) |
| Files ✅ | `GET /files/:id/(original\|thumb)?exp&sig` (signed) |
| Audit ✅ | `AUDIT_VIEW`: `GET /audit?entity&entityId` |
| Stock (M2) | A: `GET /stock`, `POST /stock/receipts`, `POST /stock/adjustments`, `GET /stock/movements` |
| QR (M2) | A: `POST /qr/assignments/:id` · `GET /qr/:code` · `GET /workers/:id/qr` |
| Assignments (M3) | A: `POST /assignments` (9/18/27 m, kitCount) · `GET /assignments` · `POST /assignments/:id/issue` (DRAFT→READY_TO_DELIVER) · `POST /assignments/:id/cancel` · W: `GET /assignments/mine` · `POST /assignments/:id/progress` · `POST /assignments/:id/ready` · `POST /assignments/:id/problem` |
| Job requests (M3) | W: `POST /job-requests` · A: `GET /job-requests` · `POST /job-requests/:id/approve`/`reject` |
| Deliveries (M3/M4) | A: `GET /deliveries?status&type` · `POST /deliveries` · `POST /deliveries/:id/complete` · `POST /deliveries/:id/cancel` |
| Map (M4) | A: `GET /map/workers?filter=all\|pickup\|delivery` (the live-location list above already carries what a marker needs; the map itself is M4) |
| Acceptance (M4) | A: `POST /assignments/:id/pickup` · `POST /assignments/:id/review` (accepted / defective / rework, photos) |
| Finance (M5) | A: `GET /workers/:id/ledger` · `POST /workers/:id/payouts` · `POST /workers/:id/bonus` · `POST /workers/:id/corrections` · W: `GET /me/finance` |
| Sales & profit (M6) | A: `POST /sales` · `GET /sales` · `POST /expenses` · `GET /expenses` · `GET /profit?from&to` |
