-- «Войти через Telegram» for staff too: their Telegram account, and staff handoff tickets.
ALTER TABLE "users" ADD COLUMN "telegramUserId" BIGINT;
CREATE UNIQUE INDEX "users_telegramUserId_key" ON "users"("telegramUserId");
ALTER TABLE "telegram_handoff_tickets" ADD COLUMN "userId" UUID;
