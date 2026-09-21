# Realtime

**Rule:** `Client → API → validation → PostgreSQL transaction → COMMIT → event bus → WebSocket`. Never emit before COMMIT; never trust client state.

## Transport
- Socket.IO on the API (`wss://api.<domain>/socket.io`), handshake `auth: { token: <access JWT> }`. Invalid/revoked session → disconnect.
- On connect: ADMIN joins room `admin`; WORKER joins `worker:<workerProfileId>` and the broadcast room `workers`. Session revocation disconnects the socket.
- Bus: Redis pub/sub channel `yusmus:events` (so the bot process and future API replicas reach all sockets). Without `REDIS_URL` an in-process emitter is used (tests).
- No replay: after reconnect the client refetches its screen data. Events are hints ("something changed"), payloads stay small and never contain full addresses, collateral details or bank-like data beyond what that audience may see.

## Envelope
```json
{ "id": "uuid", "type": "assignment.status_changed", "occurredAt": "2026-09-21T10:00:00.000Z", "data": { } }
```

## Event contracts (`packages/shared/src/events.ts`)

| Event | data | Audience |
|---|---|---|
| `worker.created` | workerId, code, fullName, status | ADMIN |
| `worker.approved` / `worker.rejected` | workerId | ADMIN, worker |
| `worker.location.updated` | workerId, latitude, longitude, receivedAt | ADMIN |
| `collateral.created` / `collateral.updated` | collateralId, workerId, type, status | ADMIN, worker (updated) |
| `job_request.created` / `job_request.decided` | requestId, workerId, kitCount / status | ADMIN / worker |
| `assignment.created` | assignmentId, workerId | ADMIN, worker |
| `assignment.status_changed` | assignmentId, workerId, from, to | ADMIN, worker |
| `work.progress_updated` | assignmentId, workerId, reportedMeters, percent | ADMIN |
| `work.ready_for_pickup` | assignmentId, workerId, meters | ADMIN |
| `delivery.created` / `delivery.completed` | deliveryId, workerId, type, assignmentId | ADMIN, worker |
| `quality.completed` | assignmentId, workerId, result, acceptedMeters | ADMIN, worker |
| `pay_rate.changed` | ratePerKit, previousRatePerKit, changedAt | ADMIN, **all workers** (room `workers`) |
| `earning.created` | workerId, assignmentId, amount | ADMIN, worker |
| `cash_payment.created` | workerId, paymentId, amount | ADMIN, worker |
| `worker.balance_updated` | workerId, balance, earned, paid | ADMIN, worker |
| `stock.updated` | materialId, quantity, low | ADMIN |
| `sale.created` / `profit.updated` | saleId / period | ADMIN |

Implemented: `worker.created/approved/rejected`, `collateral.created/updated`, `pay_rate.changed`. Others are added with their milestone; the contract file already lists all of them.
