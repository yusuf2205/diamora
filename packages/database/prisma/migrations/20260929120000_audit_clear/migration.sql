-- «Очистить журнал» (SUPER_ADMIN): the journal screen shows only what happened after the latest clear. The audit rows
-- themselves stay append-only (nobody, not even the owner, can quietly rewrite what was done) and remain in backups.
CREATE TABLE "audit_clears" (
  "id" UUID NOT NULL,
  "clearedById" UUID NOT NULL,
  "clearedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "audit_clears_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "audit_clears_clearedAt_idx" ON "audit_clears" ("clearedAt");
