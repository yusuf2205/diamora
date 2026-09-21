# REST API (`/v1`, JSON, Swagger at `/docs` in dev)

Auth: `Authorization: Bearer <access JWT>`. Errors: `{ "error": { "code", "message", "requestId", "details?" } }`. Mutations accept `Idempotency-Key`. Lists use keyset pagination (`limit`, `cursor`, `updatedSince`).
Legend: **A** = ADMIN, **W** = WORKER, ✅ = implemented in M1.

| Area | Endpoints |
|---|---|
| Auth ✅ | `POST /auth/admin/login` (phone+password) · `POST /auth/worker/code` (phone → bot sends code) · `POST /auth/worker/login` (phone+code) · `POST /auth/refresh` · `POST /auth/logout` · `POST /auth/logout-all` · `GET /auth/me` · `GET /auth/sessions` · `DELETE /auth/sessions/:id` |
| Workers ✅ | A: `GET /workers?status&q` · `GET /workers/:id` · `PATCH /workers/:id` (notes, secondary phone, phone, pause/resume) · `POST /workers/:id/approve` · `POST /workers/:id/reject` · W: `GET /workers/me` |
| Collateral ✅ | A: `GET /collaterals?workerId&status` · `GET /collaterals/:id` · `POST /collaterals/:id/receive` · `POST /collaterals/:id/return` · `POST /collaterals/:id/photos` · W: `GET /workers/me/collateral` |
| Pay rate ✅ | A+W: `GET /settings/pay-rate` → `{ ratePerKit, kitMeters: 9, updatedAt }` · A: `PUT /settings/pay-rate` `{ ratePerKit, note? }` (one global price per 9 m kit, applies to everyone; same value = `changed:false`) · A: `GET /settings/pay-rate/history` |
| Realtime ✅ | Socket.IO `wss://…/socket.io` (REALTIME.md) |
| Files ✅ | `GET /files/:id/(original\|thumb)?exp&sig` (signed) |
| Audit ✅ | A: `GET /audit?entity&entityId` |
| Catalog (M2) | A: CRUD `models`, `variants`, `colors`, `material-categories`, `materials`, `kit-templates`; W: `GET /catalog/variants` (available work) |
| Stock (M2) | A: `GET /stock`, `POST /stock/receipts`, `POST /stock/adjustments`, `GET /stock/movements` |
| QR (M2) | A: `POST /qr/assignments/:id` · `GET /qr/:code` · `GET /workers/:id/qr` |
| Assignments (M3) | A: `POST /assignments` (9/18/27 m, kitCount) · `GET /assignments` · `POST /assignments/:id/issue` (DRAFT→READY_TO_DELIVER) · `POST /assignments/:id/cancel` · W: `GET /assignments/mine` · `POST /assignments/:id/progress` · `POST /assignments/:id/ready` · `POST /assignments/:id/problem` |
| Job requests (M3) | W: `POST /job-requests` · A: `GET /job-requests` · `POST /job-requests/:id/approve|reject` |
| Deliveries (M3/M4) | A: `GET /deliveries?status&type` · `POST /deliveries` · `POST /deliveries/:id/complete` · `POST /deliveries/:id/cancel` |
| Map (M4) | A: `GET /map/workers?filter=all\|pickup\|delivery` |
| Acceptance (M4) | A: `POST /assignments/:id/pickup` · `POST /assignments/:id/review` (accepted / defective / rework, photos) |
| Finance (M5) | A: `GET /workers/:id/ledger` · `POST /workers/:id/payouts` · `POST /workers/:id/bonus` · `POST /workers/:id/corrections` · W: `GET /me/finance` |
| Sales & profit (M6) | A: `POST /sales` · `GET /sales` · `POST /expenses` · `GET /expenses` · `GET /profit?from&to` |
| Dashboard (M4+) | A: `GET /dashboard` (active workers, metres on hand, to deliver, to pick up, requests, overdue, owed cash, sales, expenses, net profit, low stock) |
