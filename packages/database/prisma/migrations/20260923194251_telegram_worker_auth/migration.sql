-- AlterTable
ALTER TABLE "colors" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- CreateTable
CREATE TABLE "telegram_login_sessions" (
    "id" UUID NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "installId" TEXT NOT NULL,
    "telegramUserId" BIGINT,
    "chatId" BIGINT,
    "linkedAt" TIMESTAMPTZ(3),
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "telegram_login_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "telegram_handoff_tickets" (
    "id" UUID NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "sessionId" UUID NOT NULL,
    "telegramUserId" BIGINT NOT NULL,
    "workerId" UUID,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "consumedAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "telegram_handoff_tickets_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "telegram_login_sessions_tokenHash_key" ON "telegram_login_sessions"("tokenHash");

-- CreateIndex
CREATE INDEX "telegram_login_sessions_telegramUserId_idx" ON "telegram_login_sessions"("telegramUserId");

-- CreateIndex
CREATE UNIQUE INDEX "telegram_handoff_tickets_tokenHash_key" ON "telegram_handoff_tickets"("tokenHash");

-- CreateIndex
CREATE INDEX "telegram_handoff_tickets_sessionId_idx" ON "telegram_handoff_tickets"("sessionId");
