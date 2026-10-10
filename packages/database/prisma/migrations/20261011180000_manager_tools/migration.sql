-- Managers: reminders to themselves, holiday cover, invitations made on the spot.
ALTER TABLE "users" ADD COLUMN "awayUntil" TIMESTAMPTZ(3);
ALTER TABLE "users" ADD COLUMN "awaySubstituteId" UUID;
ALTER TABLE "worker_profiles" ADD COLUMN "homeManagerId" UUID;
ALTER TABLE "worker_invitations" ADD COLUMN "needsApproval" BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE "staff_reminders" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "text" TEXT NOT NULL,
    "dueAt" TIMESTAMPTZ(3) NOT NULL,
    "workerId" UUID,
    "doneAt" TIMESTAMPTZ(3),
    "notifiedAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "staff_reminders_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "staff_reminders_userId_doneAt_idx" ON "staff_reminders"("userId", "doneAt");
CREATE INDEX "staff_reminders_notifiedAt_dueAt_idx" ON "staff_reminders"("notifiedAt", "dueAt");
