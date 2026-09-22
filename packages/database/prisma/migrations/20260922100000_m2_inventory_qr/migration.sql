-- M2: Materials / Stock / 9 m Kit / QR / Map (owner request, 2026-09-22). Additive only — Materials, StockMovement,
-- StockBalance, MaterialKitTemplate(Item), QrEntity already existed since M0 (unused by any API until now); this
-- migration only (a) gives MaterialCategory a stable machine `code` and seeds the fixed 5, (b) adds a KIT QR type and
-- the columns a physically-assembled kit batch QR needs. Nothing existing is altered destructively.

-- AlterEnum
-- NOTE: the new value is NOT used anywhere else in this migration (PostgreSQL forbids using an enum value added in the
-- same transaction it was added in — same pattern as the D-028 migration's SUPER_ADMIN/MANAGER role values).
ALTER TYPE "QrType" ADD VALUE 'KIT';

-- AlterTable
ALTER TABLE "material_categories" ADD COLUMN "code" TEXT;

-- AlterTable
ALTER TABLE "qr_entities" ADD COLUMN "kitTemplateId" UUID,
ADD COLUMN     "kitCount" INTEGER,
ADD COLUMN     "stockGroupId" UUID;

-- CreateIndex
CREATE UNIQUE INDEX "material_categories_code_key" ON "material_categories"("code");

-- CreateIndex
CREATE INDEX "qr_entities_kitTemplateId_idx" ON "qr_entities"("kitTemplateId");

-- AddForeignKey
ALTER TABLE "qr_entities" ADD CONSTRAINT "qr_entities_kitTemplateId_fkey" FOREIGN KEY ("kitTemplateId") REFERENCES "material_kit_templates"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ==== hand-written guards / seed ==========================================================================================

-- sanity: when a kit batch is recorded, its size is a real positive count (kept independent of the QrType CHECK below,
-- which cannot reference the enum value added above until a later migration/transaction)
ALTER TABLE "qr_entities" ADD CONSTRAINT "qr_entities_kit_count_positive" CHECK ("kitCount" IS NULL OR "kitCount" > 0);

-- fixed material categories (M2 §5): seeded once; not user-creatable in this round. `name` is the RU label an ADMIN sees.
INSERT INTO "material_categories" ("id", "code", "name") VALUES
  (gen_random_uuid(), 'TAPE', 'Лента'),
  (gen_random_uuid(), 'BEAD', 'Бисер и бусины'),
  (gen_random_uuid(), 'THREAD', 'Нить'),
  (gen_random_uuid(), 'ACCESSORY', 'Фурнитура'),
  (gen_random_uuid(), 'OTHER', 'Другое')
ON CONFLICT ("code") DO NOTHING;
