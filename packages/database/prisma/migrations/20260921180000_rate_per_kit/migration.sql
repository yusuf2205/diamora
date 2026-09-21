-- D-024: workers are paid per 9 m kit, never per metre. The column keeps its data and CHECK constraints
-- (PostgreSQL rewrites constraint definitions on RENAME COLUMN); only the name and meaning change.
ALTER TABLE "product_variants" RENAME COLUMN "ratePerMeter" TO "ratePerKit";
ALTER TABLE "work_assignments" RENAME COLUMN "ratePerMeter" TO "ratePerKit";
