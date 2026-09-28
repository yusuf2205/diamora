-- Phase 5: two-sided QR handoff. Staff scans first, the worker scans the same QR and personally confirms; material
-- custody moves to the worker only then. Materials a worker ALREADY has (work delivered under the old one-sided flow) are
-- carried over below, so her balance is right from day one.

-- CreateEnum
CREATE TYPE "HandoffStatus" AS ENUM ('AWAITING_WORKER', 'CONFIRMED', 'PROBLEM', 'EXPIRED');

-- CreateTable
CREATE TABLE "assignment_handoffs" (
    "id" UUID NOT NULL,
    "assignmentId" UUID NOT NULL,
    "workerId" UUID NOT NULL,
    "staffUserId" UUID NOT NULL,
    "qrEntityId" UUID NOT NULL,
    "status" "HandoffStatus" NOT NULL DEFAULT 'AWAITING_WORKER',
    "startedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "workerScannedAt" TIMESTAMPTZ(3),
    "workerAcceptedAt" TIMESTAMPTZ(3),
    "materialSnapshot" JSONB,
    "meters" DECIMAL(10,2) NOT NULL,
    "kitCount" INTEGER NOT NULL,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "accuracyM" DOUBLE PRECISION,
    "problemReason" TEXT,
    "problemComment" TEXT,
    "resolvedAt" TIMESTAMPTZ(3),

    CONSTRAINT "assignment_handoffs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "worker_material_balances" (
    "workerId" UUID NOT NULL,
    "materialId" UUID NOT NULL,
    "quantity" DECIMAL(14,3) NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "worker_material_balances_pkey" PRIMARY KEY ("workerId","materialId")
);

-- CreateIndex
CREATE INDEX "assignment_handoffs_assignmentId_startedAt_idx" ON "assignment_handoffs"("assignmentId", "startedAt");

-- CreateIndex
CREATE INDEX "assignment_handoffs_workerId_idx" ON "assignment_handoffs"("workerId");

-- AddForeignKey
ALTER TABLE "assignment_handoffs" ADD CONSTRAINT "assignment_handoffs_assignmentId_fkey" FOREIGN KEY ("assignmentId") REFERENCES "work_assignments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assignment_handoffs" ADD CONSTRAINT "assignment_handoffs_staffUserId_fkey" FOREIGN KEY ("staffUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_material_balances" ADD CONSTRAINT "worker_material_balances_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


-- a replay / double-tap can never produce a second receipt, and there is only one open handoff at a time
CREATE UNIQUE INDEX "assignment_handoffs_one_confirmed" ON "assignment_handoffs"("assignmentId") WHERE "status" = 'CONFIRMED';
CREATE UNIQUE INDEX "assignment_handoffs_one_awaiting" ON "assignment_handoffs"("assignmentId") WHERE "status" = 'AWAITING_WORKER';
ALTER TABLE "assignment_handoffs" ADD CONSTRAINT "assignment_handoffs_kit_count_positive" CHECK ("kitCount" > 0);
ALTER TABLE "assignment_handoffs" ADD CONSTRAINT "assignment_handoffs_confirmed_has_time"
  CHECK ("status" <> 'CONFIRMED' OR "workerAcceptedAt" IS NOT NULL);
ALTER TABLE "worker_material_balances" ADD CONSTRAINT "worker_material_balances_quantity_nonneg" CHECK ("quantity" >= 0);

-- carry-over: work that was delivered under the old flow and is still at the worker's home
INSERT INTO "stock_movements" ("id", "groupId", "type", "materialId", "quantity", "warehouseDelta", "workerDelta", "workerId", "assignmentId", "performedById", "comment")
SELECT gen_random_uuid(), gen_random_uuid(), 'ISSUE_TO_WORKER', m."materialId", m."quantity", 0, m."quantity", a."workerId", a."id", a."createdById",
       'Перенос: материалы уже у мастерицы (выдано до двусторонней передачи)'
FROM "work_assignment_materials" m JOIN "work_assignments" a ON a."id" = m."assignmentId"
WHERE a."status" IN ('DELIVERED', 'IN_PROGRESS', 'READY_FOR_PICKUP');

INSERT INTO "worker_material_balances" ("workerId", "materialId", "quantity", "updatedAt")
SELECT a."workerId", m."materialId", SUM(m."quantity"), CURRENT_TIMESTAMP
FROM "work_assignment_materials" m JOIN "work_assignments" a ON a."id" = m."assignmentId"
WHERE a."status" IN ('DELIVERED', 'IN_PROGRESS', 'READY_FOR_PICKUP')
GROUP BY a."workerId", m."materialId";
