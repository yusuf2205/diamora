-- «Заказать эту работу»: a worker requests work from the catalog (model + colour variant + 9/18/27 m); staff prepares the
-- assignment from it (FULFILLED) or declines (REJECTED); she can withdraw it (CANCELLED).
ALTER TYPE "JobRequestStatus" ADD VALUE IF NOT EXISTS 'CANCELLED';
ALTER TABLE "worker_job_requests" ADD COLUMN "productModelId" UUID, ADD COLUMN "productVariantId" UUID, ADD COLUMN "colorId" UUID;
ALTER TABLE "worker_job_requests" ADD CONSTRAINT "worker_job_requests_productModelId_fkey" FOREIGN KEY ("productModelId") REFERENCES "product_models"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "worker_job_requests" ADD CONSTRAINT "worker_job_requests_productVariantId_fkey" FOREIGN KEY ("productVariantId") REFERENCES "product_variants"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "worker_job_requests" ADD CONSTRAINT "worker_job_requests_colorId_fkey" FOREIGN KEY ("colorId") REFERENCES "colors"("id") ON DELETE SET NULL ON UPDATE CASCADE;
-- one open request per worker at a time: a double tap or a second request never creates a queue of duplicates
CREATE UNIQUE INDEX "worker_job_requests_one_pending" ON "worker_job_requests"("workerId") WHERE "status" = 'PENDING';
