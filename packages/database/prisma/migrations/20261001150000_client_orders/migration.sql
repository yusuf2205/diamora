-- Customer orders from the form on diamoraa.uz («Заказать»).
CREATE TYPE "ClientOrderStatus" AS ENUM ('NEW', 'CONFIRMED', 'IN_WORK', 'DONE', 'CANCELLED');
CREATE TABLE "client_orders" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "productModelId" UUID,
    "colorName" TEXT,
    "quantity" DECIMAL(10,2),
    "comment" TEXT,
    "status" "ClientOrderStatus" NOT NULL DEFAULT 'NEW',
    "staffNote" TEXT,
    "handledById" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "client_orders_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "client_orders_quantity_pos" CHECK ("quantity" IS NULL OR "quantity" > 0)
);
CREATE UNIQUE INDEX "client_orders_code_key" ON "client_orders"("code");
CREATE INDEX "client_orders_status_createdAt_idx" ON "client_orders"("status", "createdAt");
ALTER TABLE "client_orders" ADD CONSTRAINT "client_orders_productModelId_fkey" FOREIGN KEY ("productModelId") REFERENCES "product_models"("id") ON DELETE SET NULL ON UPDATE CASCADE;
