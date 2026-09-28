-- «Добавить мастерицу» by invitation link + «Удалить мастерицу» (full erase of a worker WITHOUT history).

CREATE TABLE "worker_invitations" (
    "id" UUID NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "fullName" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "managerId" UUID,
    "createdById" UUID NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "usedAt" TIMESTAMPTZ(3),
    "workerId" UUID,
    "revokedAt" TIMESTAMPTZ(3),
    CONSTRAINT "worker_invitations_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "worker_invitations_tokenHash_key" ON "worker_invitations"("tokenHash");
CREATE INDEX "worker_invitations_phone_idx" ON "worker_invitations"("phone");

-- Append-only stays append-only. ONE narrow exception: the declared-collateral trail (history + photos) of a worker
-- who is being erased because she never had any work, money or received collateral. The application sets
-- `yusmus.worker_purge = 'on'` with SET LOCAL inside that single transaction only; audit_logs, the cash ledger,
-- stock movements and status history can never be deleted.
CREATE OR REPLACE FUNCTION forbid_mutation() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'DELETE' AND TG_TABLE_NAME IN ('collateral_history', 'collateral_photos')
     AND current_setting('yusmus.worker_purge', true) = 'on' THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'table "%" is append-only: % is not allowed (use a compensating record)', TG_TABLE_NAME, TG_OP
    USING ERRCODE = 'restrict_violation';
END;
$$ LANGUAGE plpgsql;
