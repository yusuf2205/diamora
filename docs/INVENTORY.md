# Materials, Stock, 9 m Kits, QR (M2)

Materials, `StockMovement`, `StockBalance`, `MaterialKitTemplate(Item)` and `QrEntity` were already part of the M0 schema
(unused by any API until now). M2 adds the `INVENTORY_VIEW`/`INVENTORY_MANAGE`-gated API + Flutter UI that make them real,
plus the small additive pieces a KIT QR needed (`QrType.KIT`, a `code` on `MaterialCategory`).

## Materials — a normal reference book

Categories are **fixed and seeded** (`TAPE`/`BEAD`/`THREAD`/`ACCESSORY`/`OTHER`, owner's §5 list) as `MaterialCategory` rows —
a lookup table, not a hard Postgres enum, so the RU display name can be renamed later without a migration. There is no
"create category" endpoint in this round (by design: the set is fixed). `unit` is `METER`/`GRAM`/`PCS`/`SET`/`ROLL`/`PACKAGE`.
A material is never hard-deleted — `POST .../:id/deactivate` only.

**No financial field is ever computed here beyond `unitCost`** (used only by the future M6 profit report). The catalog
module never joins this table; a WORKER has no route into it at all.

## Stock — a ledger, not a mutable counter

Every change is an immutable `StockMovement` row (DB trigger, `db-guards.spec.ts`); `StockBalance` is a materialised
cache of Σ`warehouseDelta`, updated in the SAME transaction under a row lock (`lockMaterialBalance`) so two concurrent
movements on the same material can never both pass the "stock ≥ 0" check — belt. The `stock_balances_quantity_nonneg`
CHECK (already in the M0 integrity-guards migration) is the suspenders. A wrong entry is fixed with a compensating
`ADJUSTMENT_IN`/`ADJUSTMENT_OUT`, never an edit. Movement types: `RECEIPT`, `ISSUE_TO_KIT` (= "KIT_ASSEMBLY" in the owner's
wording — kept the existing M0 name rather than renaming a working enum), `ISSUE_TO_WORKER`/`RETURN_FROM_WORKER`/`CONSUMPTION`
(reserved for M3's assignment flow), `ADJUSTMENT_IN`/`OUT`, `WRITE_OFF`.

## The 9 m kit — one recipe, multiplied

`MaterialKitTemplate` names what one 9 m set needs (ribbon + beads + thread + extras: `MaterialKitTemplateItem.requiredQuantity`
per material). **18/27 m are NOT separate templates** — `POST .../:id/assemble { count: 2|3 }` multiplies every
`requiredQuantity` by `count` and consumes that from the warehouse in one atomic group of `ISSUE_TO_KIT` movements
(shared `groupId`). Assembly is refused whole (409, nothing partially consumed) if any single ingredient is short.

## QR (D-012 architecture, extended)

The opaque code format is unchanged (`YQ1.<12 chars>`, no personal data ever encoded in it). `QrType` gained a third
value, `KIT`: a physically-assembled batch, created by `assemble()` alongside its stock movements
(`QrEntity.kitTemplateId`/`kitCount`/`stockGroupId`). `WORKER` codes are unchanged — generated automatically at approval
(`WorkersService.approve`), now also **returned** as `qrCode` on `GET /workers/:id` so staff can show/print it.

`GET /v1/qr/:code` resolves either kind:
- `WORKER` → reuses `WorkersService.get()` verbatim, so a MANAGER scanning a worker outside her scope gets the exact
  same 404 `GET /workers/:id` would give — never the data, never a 403 that reveals the worker exists.
- `KIT` → the assembled batch's composition, gated by `INVENTORY_VIEW`.
- An invalid, unknown or revoked code is a plain 404. A WORKER role may not call this route at all (403).
- `ASSIGNMENT` is not reachable yet — nothing creates one (WorkAssignment is M3) — but the same `QrEntity` row shape
  and the same resolve endpoint are ready for it; no separate architecture will be needed later.

## Flutter

- `features/inventory/inventory_screen.dart` — two tabs (Materials, Kits). Materials: balances with a low-stock flag
  (`balance < minStock`), a FAB offering "New material" or "Receipt". Kits: templates list, "Assemble" per row (asks
  the count, shows the resulting QR with `qr_flutter`).
- `features/qr/qr_scanner_screen.dart` — `mobile_scanner`; a WORKER code opens Worker Detail, a KIT code shows its
  composition in a bottom sheet, anything else is a clear "not found" — never a fake success. Reachable from an AppBar
  action on the Workers and Inventory screens (not a bottom-nav tab or a global FAB — scanning is an action, not a
  destination, and a screen-level FAB was already taken on Team/Inventory).
- `features/workers/worker_detail_screen.dart` — an AppBar QR icon shows a worker's own code (`qr_flutter`, rendered
  locally from the text — nothing downloaded).

## Realtime

`material.created`/`.updated`, `stock.movement.created`, `stock.updated`, `kit.created`/`.updated`, `kit.assembled`,
`qr.created` — all routed to staff with `INVENTORY_VIEW` (see [REALTIME.md](REALTIME.md)). Workers never need these.

## Known gap (discovered, not introduced this round)

`ProductVariant`/`Color` management (picking a colour when adding a catalog variant) has **no UI in either app** —
the repository method existed on mobile from the RBAC/Catalog round but was never wired to a screen, and there is no
`GET /colors` endpoint to list them from. Out of scope for M2 (§22 asks for photo/video/publish/hide/new, not colour
management); flagged here so it is not silently lost.

## Testing

`apps/api/test/materials.spec.ts` (5), `stock.spec.ts` (6: receipt, adjust IN/OUT, negative-balance refusal, write-off,
**concurrent movements never go negative**, permission boundary, realtime), `kits.spec.ts` (4: 9→18 m multiplication
with a shared `groupId`, insufficient-stock refusal leaves the balance untouched, permission boundary, realtime),
`qr.spec.ts` (4: worker QR round-trip, manager-scope 404, kit QR + `INVENTORY_VIEW` boundary, invalid/revoked code +
WORKER-role 403) — 25 tests total, real PostgreSQL. `apps/mobile/test/inventory_test.dart` (3), `qr_test.dart` (3, pure
`classifyQr` — no camera needed), `map_marker_test.dart` (3, shared with [YANDEX-MAPS.md](YANDEX-MAPS.md)).
