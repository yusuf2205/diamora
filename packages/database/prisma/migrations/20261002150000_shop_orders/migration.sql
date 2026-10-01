-- Customer orders from shop.diamoraa.uz and the shop bot (owner, 2026-10-01); staff still write them down in the panel.
ALTER TABLE "client_orders" ADD COLUMN "source" TEXT NOT NULL DEFAULT 'PANEL', ADD COLUMN "customerChatId" BIGINT;
-- orders taken before today came from the old form on diamoraa.uz or from staff; they stay PANEL
CREATE INDEX "client_orders_customerChatId_idx" ON "client_orders"("customerChatId");
