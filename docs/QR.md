# QR

A QR contains **only an opaque code** — never a name, phone, address or amount.

- Format: `YQ1.<12 chars base32>` (e.g. `YQ1.K7M2QX9TPD4R`). Table `qr_entities(code, type, assignmentId?, workerId?, revokedAt?)`.
- Types: `ASSIGNMENT` (kit/job label, generated when the assignment becomes READY_TO_DELIVER) and `WORKER` (personal card, generated on approval).
- Flutter: render with `qr_flutter`, scan with `mobile_scanner`. Only ADMIN can resolve.

## Resolve — `GET /v1/qr/:code`
Returns `{ type, assignment?, worker }` where `worker` is the **full worker card** (same DTO as `GET /v1/workers/:id/card`): contacts, GPS, collateral, active assignments, materials on hand, current metres, progress, deadlines, to-deliver / to-pick-up, earned / paid / owed, recent history, and suggested quick actions.

## Scan flows
1. **Issue / receive** — scan assignment QR → card opens with `Выдать ещё 9 м · Создать доставку · Забрать работу · Принять · Выплатить наличными · История`.
2. **Meeting** — scan worker QR → same card (useful for payouts).
3. Revoked/unknown code → 404 with a clear message; every resolve is audited.
