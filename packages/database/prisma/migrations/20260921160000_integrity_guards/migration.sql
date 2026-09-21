-- Integrity guards that Prisma cannot express. Business invariants hold at the DATABASE level, whatever the application does.

-- 1. Append-only tables: UPDATE / DELETE / TRUNCATE are rejected. Corrections are compensating rows (D-010).
CREATE OR REPLACE FUNCTION forbid_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'table "%" is append-only: % is not allowed (use a compensating record)', TG_TABLE_NAME, TG_OP
    USING ERRCODE = 'restrict_violation';
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'audit_logs',
    'worker_ledger_transactions',
    'collateral_history',
    'collateral_photos',
    'stock_movements',
    'work_assignment_status_history'
  ] LOOP
    EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION forbid_mutation()', t || '_immutable', t);
    EXECUTE format('CREATE TRIGGER %I BEFORE TRUNCATE ON %I FOR EACH STATEMENT EXECUTE FUNCTION forbid_mutation()', t || '_no_truncate', t);
  END LOOP;
END $$;

-- 2. Stock can never go negative; movements have a positive magnitude
ALTER TABLE stock_balances ADD CONSTRAINT stock_balances_quantity_nonneg CHECK (quantity >= 0);
ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_quantity_positive CHECK (quantity > 0);

-- 3. Assignment metres: accepted + defective can never exceed what was brought back; everything non-negative
ALTER TABLE work_assignments ADD CONSTRAINT work_assignments_meters_consistent CHECK (
  "plannedMeters" > 0 AND "reportedMeters" >= 0 AND "deliveredMeters" >= 0 AND "acceptedMeters" >= 0 AND "defectiveMeters" >= 0
  AND "acceptedMeters" + "defectiveMeters" <= "deliveredMeters"
);
ALTER TABLE work_assignments ADD CONSTRAINT work_assignments_money_sane CHECK ("ratePerMeter" >= 0 AND "calculatedPayment" >= 0);
ALTER TABLE work_assignments ADD CONSTRAINT work_assignments_kit_count CHECK ("kitCount" BETWEEN 1 AND 3);
ALTER TABLE worker_job_requests ADD CONSTRAINT worker_job_requests_kit_count CHECK ("kitCount" BETWEEN 1 AND 3);
ALTER TABLE quality_inspections ADD CONSTRAINT quality_inspections_meters_consistent CHECK (
  "broughtMeters" >= 0 AND "acceptedMeters" >= 0 AND "defectiveMeters" >= 0 AND "reworkMeters" >= 0
  AND "acceptedMeters" + "defectiveMeters" + "reworkMeters" <= "broughtMeters"
);
ALTER TABLE work_progress ADD CONSTRAINT work_progress_sane CHECK ("reportedMeters" >= 0 AND percent >= 0 AND percent <= 100);

-- 4. Money
ALTER TABLE cash_payments ADD CONSTRAINT cash_payments_amount_positive CHECK (amount > 0);
ALTER TABLE worker_ledger_transactions ADD CONSTRAINT worker_ledger_amount_nonzero CHECK (amount <> 0);
ALTER TABLE worker_collaterals ADD CONSTRAINT worker_collaterals_amounts_nonneg CHECK (
  (amount IS NULL OR amount >= 0) AND ("estimatedValue" IS NULL OR "estimatedValue" >= 0)
);
ALTER TABLE sales ADD CONSTRAINT sales_total_nonneg CHECK (total >= 0);
ALTER TABLE sale_items ADD CONSTRAINT sale_items_sane CHECK (quantity > 0 AND "unitPrice" >= 0 AND "totalPrice" >= 0);
ALTER TABLE expenses ADD CONSTRAINT expenses_amount_positive CHECK (amount > 0);
ALTER TABLE product_variants ADD CONSTRAINT product_variants_rate_nonneg CHECK ("ratePerMeter" >= 0);
ALTER TABLE material_kit_template_items ADD CONSTRAINT kit_items_qty_positive CHECK ("requiredQuantity" > 0);

-- 5. GPS sanity
ALTER TABLE worker_profiles ADD CONSTRAINT worker_profiles_gps_range CHECK (
  (latitude IS NULL OR latitude BETWEEN -90 AND 90) AND (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

-- 6. Self-check views (must stay empty; verified hourly by the worker container)
CREATE OR REPLACE VIEW ledger_balance_mismatches AS
SELECT w.id AS "workerId", w.balance AS materialised, COALESCE(SUM(l.amount), 0) AS ledger
FROM worker_profiles w
LEFT JOIN worker_ledger_transactions l ON l."workerId" = w.id
GROUP BY w.id, w.balance
HAVING w.balance <> COALESCE(SUM(l.amount), 0);

CREATE OR REPLACE VIEW stock_balance_mismatches AS
SELECT b."materialId", b.quantity AS materialised, COALESCE(SUM(m."warehouseDelta"), 0) AS movements
FROM stock_balances b
LEFT JOIN stock_movements m ON m."materialId" = b."materialId"
GROUP BY b."materialId", b.quantity
HAVING b.quantity <> COALESCE(SUM(m."warehouseDelta"), 0);

-- 7. What each worker holds right now (derived from movements, D-011)
CREATE OR REPLACE VIEW worker_material_holdings AS
SELECT "workerId", "materialId", SUM("workerDelta") AS quantity
FROM stock_movements
WHERE "workerId" IS NOT NULL
GROUP BY "workerId", "materialId"
HAVING SUM("workerDelta") <> 0;
