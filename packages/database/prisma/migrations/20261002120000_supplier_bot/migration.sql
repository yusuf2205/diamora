-- Orders go to the supplier's Telegram through our bot; the supplier answers with buttons.
ALTER TABLE "suppliers" ADD COLUMN "telegramChatId" BIGINT, ADD COLUMN "linkTokenHash" TEXT, ADD COLUMN "linkExpiresAt" TIMESTAMPTZ(3);
CREATE UNIQUE INDEX "suppliers_telegramChatId_key" ON "suppliers"("telegramChatId");
CREATE UNIQUE INDEX "suppliers_linkTokenHash_key" ON "suppliers"("linkTokenHash");
ALTER TABLE "purchase_orders" ADD COLUMN "sentByBotAt" TIMESTAMPTZ(3), ADD COLUMN "supplierReply" TEXT, ADD COLUMN "supplierReplyAt" TIMESTAMPTZ(3);
