-- «Закупки»: suppliers, orders to them, and where each material is usually bought.
CREATE TYPE "PurchaseStatus" AS ENUM ('DRAFT', 'ORDERED', 'RECEIVED', 'CANCELLED');

CREATE TABLE "suppliers" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "phone" TEXT,
    "telegram" TEXT,
    "note" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "suppliers_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "purchase_orders" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "supplierId" UUID,
    "status" "PurchaseStatus" NOT NULL DEFAULT 'DRAFT',
    "note" TEXT,
    "createdById" UUID NOT NULL,
    "orderedAt" TIMESTAMPTZ(3),
    "receivedAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "purchase_orders_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "purchase_orders_code_key" ON "purchase_orders"("code");
CREATE INDEX "purchase_orders_status_createdAt_idx" ON "purchase_orders"("status", "createdAt");
ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "suppliers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "purchase_order_items" (
    "id" UUID NOT NULL,
    "orderId" UUID NOT NULL,
    "materialId" UUID NOT NULL,
    "quantity" DECIMAL(14,3) NOT NULL,
    "unitPrice" BIGINT,
    CONSTRAINT "purchase_order_items_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "purchase_order_items_quantity_pos" CHECK ("quantity" > 0),
    CONSTRAINT "purchase_order_items_price_nonneg" CHECK ("unitPrice" IS NULL OR "unitPrice" >= 0)
);
CREATE INDEX "purchase_order_items_orderId_idx" ON "purchase_order_items"("orderId");
ALTER TABLE "purchase_order_items" ADD CONSTRAINT "purchase_order_items_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "purchase_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "purchase_order_items" ADD CONSTRAINT "purchase_order_items_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "materials" ADD COLUMN "supplierId" UUID;
ALTER TABLE "materials" ADD CONSTRAINT "materials_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "suppliers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
