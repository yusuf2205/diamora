-- In-app notifications (bell + Android notification) instead of Telegram: one row per recipient (channel APP).
ALTER TABLE "notifications" ADD COLUMN "userId" UUID, ADD COLUMN "title" TEXT, ADD COLUMN "link" TEXT, ADD COLUMN "dedupeKey" TEXT;
CREATE UNIQUE INDEX "notifications_dedupeKey_key" ON "notifications"("dedupeKey");
CREATE INDEX "notifications_userId_createdAt_idx" ON "notifications"("userId", "createdAt");
