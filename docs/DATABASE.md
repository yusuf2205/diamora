# Database (PostgreSQL 17 on the NAS)

Source: `packages/database/prisma/schema.prisma` (+ hand-written guards in `migrations/*_integrity_guards`).
Conventions: UUIDv7 ids, `timestamptz` UTC, money `BigInt` (UZS), metres `Decimal(10,2)`, quantities `Decimal(14,3)`.

## Groups

| Group | Tables |
|---|---|
| Access | `users` (role `SUPER_ADMIN`\|`ADMIN`\|`MANAGER`\|`WORKER`, `lastSeenAt`), `user_permissions` (per-user overrides, D-028), `user_sessions`, `login_attempts`, `login_codes` (worker one-time codes, hashed) |
| Workers | `worker_profiles` (`assignedManagerId` → a `MANAGER` user, D-028), `worker_locations` (GPS history from Telegram), `registration_drafts` (bot conversation state) |
| Live location | `user_live_locations` (one row per user — the latest position only, D-030) |
| Collateral | `worker_collaterals`, `collateral_photos`, `collateral_history` (immutable) |
| Catalog | `product_models` (`status`/`availability`/`isNew`/`sortOrder`, D-029), `product_variants`, `product_media` (photos/videos, one `isMain`), `colors`, `company_contact_settings` (single row), `material_categories`, `materials`, `material_kit_templates`, `material_kit_template_items` |
| Stock | `stock_movements` (immutable), `stock_balances` (CHECK ≥ 0), view `worker_material_holdings` |
| Production | `work_assignments`, `work_assignment_materials`, `work_assignment_status_history` (immutable), `work_progress`, `worker_job_requests`, `quality_inspections`, `deliveries`, `delivery_items`, `qr_entities` |
| Money | `pay_rate_changes` (immutable history of the ONE global 9 m price), `worker_ledger_transactions` (immutable), `cash_payments`, `sales`, `sale_items`, `expenses` |
| Platform | `notifications` (outbox + in-app), `audit_logs` (immutable), `file_assets`, `idempotency_keys`, `sequences` |

## Integrity guards (in the DB, not only in code)

- Triggers reject UPDATE/DELETE/TRUNCATE on the immutable tables.
- CHECK: stock ≥ 0; `acceptedMeters + defectiveMeters ≤ deliveredMeters`; amounts ≥ 0/`> 0`; GPS in range (both `worker_profiles` and `user_live_locations`); one active `HELD` collateral of a type per row is not required — but only one `PENDING/HELD` MONEY collateral per registration is created by the bot.
- Trigger: `worker_profiles.assignedManagerId` must reference a user whose `role = 'MANAGER'` (checked in the database, not only in the service).
- Unique: phone, telegram user id, worker code, QR code, ledger reversal, `(userId, permission)` on `user_permissions`.
- View `ledger_balance_mismatches` (must be empty) — checked hourly by the worker.

## Files
Bytes live in MinIO. `file_assets` keeps bucket, key, mime, size, sha256, dimensions, uploader.
