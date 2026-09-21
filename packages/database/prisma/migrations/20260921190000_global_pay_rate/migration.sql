-- D-027: ONE global price for a 9 m kit (30 000 UZS at the start), changeable by ADMIN at any moment, valid for everyone.
-- It replaces the per-variant / per-assignment rates of D-024's first cut. Open work is paid at the current rate;
-- accepted work keeps the amount already written to the immutable ledger.

-- 1. history of the global rate (append-only) + the initial value
CREATE TABLE "pay_rate_changes" (
    "id" UUID NOT NULL,
    "seq" SERIAL NOT NULL,
    "ratePerKit" BIGINT NOT NULL,
    "previousRatePerKit" BIGINT,
    "changedById" UUID,
    "note" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "pay_rate_changes_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "pay_rate_changes_seq_key" ON "pay_rate_changes"("seq");
ALTER TABLE "pay_rate_changes" ADD CONSTRAINT "pay_rate_changes_rate_positive" CHECK ("ratePerKit" > 0 AND ("previousRatePerKit" IS NULL OR "previousRatePerKit" > 0));
CREATE TRIGGER "pay_rate_changes_immutable" BEFORE UPDATE OR DELETE ON "pay_rate_changes" FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
CREATE TRIGGER "pay_rate_changes_no_truncate" BEFORE TRUNCATE ON "pay_rate_changes" FOR EACH STATEMENT EXECUTE FUNCTION forbid_mutation();
INSERT INTO "pay_rate_changes" ("id", "ratePerKit", "note") VALUES (gen_random_uuid(), 30000, 'Начальная ставка: 30 000 сум за 9 м');

-- 2. no per-variant rate any more
ALTER TABLE "product_variants" DROP CONSTRAINT "product_variants_rate_nonneg";
ALTER TABLE "product_variants" DROP COLUMN "ratePerKit";

-- 3. assignments no longer copy a rate at creation; they record the rate that applied when the work was accepted
ALTER TABLE "work_assignments" DROP CONSTRAINT "work_assignments_money_sane";
ALTER TABLE "work_assignments" RENAME COLUMN "ratePerKit" TO "settledRatePerKit";
ALTER TABLE "work_assignments" ALTER COLUMN "settledRatePerKit" DROP NOT NULL;
UPDATE "work_assignments" SET "settledRatePerKit" = NULL; -- creation-time copies carry no meaning under the global rate
ALTER TABLE "work_assignments" ADD CONSTRAINT "work_assignments_money_sane" CHECK (("settledRatePerKit" IS NULL OR "settledRatePerKit" > 0) AND "calculatedPayment" >= 0);
