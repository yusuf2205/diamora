# Finance (cash only)

No Payme/Click/cards/gateways. Money = whole UZS (`BigInt`), sent as strings.

## Worker ledger (`worker_ledger_transactions`, immutable)
`EARNING` (+) · `PAYOUT_CASH` (−) · `BONUS` (+) · `CORRECTION` (±, compensating). No fines on the MVP.
`balance = Σ amount`; `earned = Σ EARNING+BONUS(+CORRECTION>0)`; `paid = Σ |PAYOUT_CASH|`. The profile keeps materialised `balance` updated in the same transaction under a row lock; the hourly job checks `Σ ledger = balance`.

## Earning (on acceptance) — we pay per 9 m kit, never per metre (D-024)
The price is **one global number: UZS per 9 m kit** — 30 000 at the start (D-027). An assignment is 1, 2 or 3 kits (9 / 18 / 27 m), so its price is `kits × price`: 9 m = 30 000, 18 m = 60 000, 27 m = 90 000.

`amount = round_half_up(ratePerKit × acceptedCm / 900)` (integer arithmetic in centimetres; `earningFor` in `packages/shared`). Whole accepted kits are exact multiples of the rate. A kit that is only partly accepted (defect, shortfall) is paid pro rata (confirmed by the owner). Switching to "whole kits only" later would be a one-line change: floor `acceptedCm` to a multiple of 900 in `earningFor`.

### Changing the price (`PAY_RATE_MANAGE`, any moment)
Profile → **Ставка за 9 м** → *Изменить ставку*. `SUPER_ADMIN` always has this permission; `ADMIN` only if explicitly granted (§39); `MANAGER`/`WORKER` never (D-028, [RBAC.md](RBAC.md)). The change is one new row in the append-only `pay_rate_changes` (previous → new, who, when, note), is audited, and is pushed to every open staff and WORKER screen (`pay_rate.changed`). It applies to **everyone at once**:

| Work | Price used |
|---|---|
| not yet accepted (issued, in progress, brought back) | the **current** price, evaluated when it is accepted |
| accepted / already in the ledger, paid or not | **unchanged** — the amount was written to the immutable ledger; `settledRatePerKit` records the price used |

A mistake is fixed by setting the price again (history keeps both). Workers see the current price on their home screen; the app also shows the expected amount of an open assignment as `kits × current price`.

## Cash payout
"Выплатить наличными" (`CASH_PAYOUT`; a MANAGER can be granted it for her own workers): screen shows *К выплате* (= balance); choose full or other amount → `CashPayment` + `PAYOUT_CASH` in one transaction → `cash_payment.created` + `worker.balance_updated`. Amount ≤ balance unless the actor passes `force=true` (audited).

## Who sees whose money (`FINANCE_VIEW_ALL` / `_ASSIGNED`, D-028)
`SUPER_ADMIN`/`ADMIN` (default) see every worker's ledger and balance. A `MANAGER` sees only her own assigned workers' — enforced server-side (`scopeFor(..., 'FINANCE')`), the same way as everywhere else. A `WORKER` sees only her own (`GET /workers/me`).

## Worker screen wording
**К получению** (balance) · **Заработано** · **Выплачено** · history: `+450 000 — Rose Gold`, `−900 000 — выплата наличными`.

## Sales, expenses, net profit (M6)
`Sale` + `SaleItem`; `Expense` (`DELIVERY_FUEL`, `PACKAGING`, `OTHER`). Buying raw materials is **not** an expense of the period.

```
Net profit = Sales revenue
           − cost of materials actually used (CONSUMPTION movements × unit cost)
           − worker earnings (EARNING + BONUS for the period)
           − delivery/fuel − packaging − other linked expenses
Margin = Net profit / Revenue
```
Collateral is never income. Periods: today, yesterday, week, month, custom. Later: per model, colour, per kit.
