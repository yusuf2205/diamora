-- «Удалить» for things that already have history (work, money, stock movements): the row stays so old work, reports
-- and the append-only trail keep pointing at something real, but it disappears from every list and cannot be used again.
-- Things with no history are still erased for real (see the services).
ALTER TABLE "product_models" ADD COLUMN "deletedAt" TIMESTAMPTZ(3);
ALTER TABLE "materials" ADD COLUMN "deletedAt" TIMESTAMPTZ(3);
ALTER TABLE "material_kit_templates" ADD COLUMN "deletedAt" TIMESTAMPTZ(3);
ALTER TABLE "worker_profiles" ADD COLUMN "deletedAt" TIMESTAMPTZ(3);

CREATE INDEX "worker_profiles_live_idx" ON "worker_profiles" ("status") WHERE "deletedAt" IS NULL;
