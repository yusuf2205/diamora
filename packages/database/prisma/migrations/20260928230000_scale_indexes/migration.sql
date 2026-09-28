-- Scale: indexes for the hot reads that grow with the business (reports by period, the evening summary, the bell badge).
CREATE INDEX IF NOT EXISTS "quality_inspections_inspectedAt_idx" ON "quality_inspections"("inspectedAt");
CREATE INDEX IF NOT EXISTS "worker_ledger_transactions_type_createdAt_idx" ON "worker_ledger_transactions"("type", "createdAt");
CREATE INDEX IF NOT EXISTS "work_assignments_createdAt_idx" ON "work_assignments"("createdAt");
CREATE INDEX IF NOT EXISTS "notifications_userId_readAt_idx" ON "notifications"("userId", "readAt");
