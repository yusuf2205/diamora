# Business rules & state machines

## Invariants (enforced in services AND, where possible, by PostgreSQL)

1. Nothing can be issued that is not in stock; stock never goes negative (`CHECK quantity >= 0`).
2. Every stock change is a `StockMovement` (append-only); balances are derived and materialised in the same transaction.
3. The money ledger is append-only. Corrections = `CORRECTION` rows. Balance = Σ ledger, materialised on the profile in the same transaction (row lock) and verified by an integrity job.
4. Collateral history, assignment status history, audit log are append-only (DB triggers).
5. `acceptedMeters + defectiveMeters ≤ deliveredMeters` (CHECK).
6. **Pay is per 9 m kit at ONE global price** (30 000 UZS at the start, D-027). ADMIN may change it at any moment; it applies to everyone. Work not yet accepted is paid at the current price; accepted work is never recalculated.
7. A cash payout can never exceed the worker's balance without an explicit `force` flag from ADMIN (recorded in audit).
8. Only the server decides: the client only requests; realtime events are sent after COMMIT.
8. A worker sees only her own data. ADMIN sees everything. Deny by default.
9. Collateral is not income; sales are not linked to collateral.
10. Critical operations are idempotent (`Idempotency-Key`).

## WorkerProfile status

```
PENDING_APPROVAL ──approve──► ACTIVE ◄──resume── PAUSED
       │                         │ └─pause────────►
       └────reject──► REJECTED   └──archive──► ARCHIVED
```
Registration (Telegram) creates `PENDING_APPROVAL`. Approve → creates `User(WORKER)` + personal QR + Telegram message.

## Collateral

`PENDING` (declared in Telegram) → `HELD` (ADMIN confirmed physical receipt; `receivedAt/By`) → `RETURNED` (`returnedAt/By`, worker confirmation note).
Every step and every photo appends `CollateralHistory`. `MONEY` has `amount`; `ITEM` has `description` (+ optional `estimatedValue`) and photos.

## WorkAssignment (statuses as in the brief)

| From | To | Who | Side effects |
|---|---|---|---|
| DRAFT | READY_TO_DELIVER | ADMIN | kit materials leave the warehouse (`ISSUE_TO_KIT`, stock check), QR generated, delivery `DELIVERY_TO_WORKER` created |
| DRAFT / READY_TO_DELIVER | CANCELLED | ADMIN | issued materials returned (`ADJUSTMENT_IN`), delivery cancelled |
| READY_TO_DELIVER | DELIVERED | ADMIN (delivery completed) | `ISSUE_TO_WORKER` movements → worker holds materials |
| DELIVERED | IN_PROGRESS | SYSTEM (first progress) / WORKER | – |
| IN_PROGRESS | READY_FOR_PICKUP | WORKER | shows on ADMIN map "Есть что забрать", pickup delivery created |
| READY_FOR_PICKUP | IN_PROGRESS | WORKER | reopen |
| READY_FOR_PICKUP | PICKED_UP | ADMIN (pickup completed) | – |
| PICKED_UP | UNDER_REVIEW | ADMIN / SYSTEM | – |
| UNDER_REVIEW | ACCEPTED / PARTIALLY_ACCEPTED / REWORK_REQUIRED | ADMIN | `QualityInspection`; `CONSUMPTION` + `RETURN_FROM_WORKER` movements; **EARNING** ledger row for accepted metres |
| ACCEPTED / PARTIALLY_ACCEPTED | COMPLETED | SYSTEM / ADMIN | closes the assignment |
| PARTIALLY_ACCEPTED | REWORK_REQUIRED | ADMIN | remainder goes back |
| REWORK_REQUIRED | IN_PROGRESS | ADMIN | after redelivery |

No other transitions exist; each applied transition appends `WorkAssignmentStatusHistory` (who, when, comment) in the same transaction.

## Delivery
Types `DELIVERY_TO_WORKER`, `PICKUP_FROM_WORKER`. Statuses `PENDING → COMPLETED | CANCELLED`. Completing a delivery moves the linked assignment (DELIVERED / PICKED_UP) in one transaction.

## Job request
`PENDING → APPROVED → FULFILLED` or `PENDING → REJECTED`. `FULFILLED` when an assignment is created from it.

## Registration flow (Telegram)
See TELEGRAM-BOT.md. The flow is a pure state machine in `packages/shared/src/registration.ts`, unit-tested.

## Worker motivation (ethical)
Progress, remaining metres, recommended daily pace ("2 м в день"), milestones. No shaming, no fake timers, no fines on the MVP.
