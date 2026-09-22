-- D-028/D-029/D-030: SUPER_ADMIN + MANAGER roles, permission overrides, manager assignment, catalog (Наши работы), company contact settings,
-- live location and presence. Additive only: nothing existing is altered destructively; existing ADMIN/WORKER rows are untouched.

-- CreateEnum
CREATE TYPE "CatalogStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'HIDDEN');

-- CreateEnum
CREATE TYPE "CatalogAvailability" AS ENUM ('AVAILABLE', 'ON_REQUEST', 'UNAVAILABLE');

-- CreateEnum
CREATE TYPE "MediaKind" AS ENUM ('PHOTO', 'VIDEO');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "Role" ADD VALUE 'SUPER_ADMIN';
ALTER TYPE "Role" ADD VALUE 'MANAGER';

-- AlterTable
ALTER TABLE "product_models" ADD COLUMN     "availability" "CatalogAvailability" NOT NULL DEFAULT 'AVAILABLE',
ADD COLUMN     "isNew" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "publishedAt" TIMESTAMPTZ(3),
ADD COLUMN     "sortOrder" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "status" "CatalogStatus" NOT NULL DEFAULT 'DRAFT';

-- AlterTable
ALTER TABLE "product_variants" ADD COLUMN     "label" TEXT,
ADD COLUMN     "sortOrder" INTEGER NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "lastSeenAt" TIMESTAMPTZ(3);

-- AlterTable
ALTER TABLE "worker_profiles" ADD COLUMN     "assignedManagerId" UUID;

-- CreateTable
CREATE TABLE "product_media" (
    "id" UUID NOT NULL,
    "productModelId" UUID NOT NULL,
    "variantId" UUID,
    "fileId" UUID NOT NULL,
    "kind" "MediaKind" NOT NULL DEFAULT 'PHOTO',
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isMain" BOOLEAN NOT NULL DEFAULT false,
    "caption" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "product_media_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "company_contact_settings" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "phone" TEXT,
    "telegramUsername" TEXT,
    "telegramUrl" TEXT,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "updatedById" UUID,

    CONSTRAINT "company_contact_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_permissions" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "permission" TEXT NOT NULL,
    "granted" BOOLEAN NOT NULL,
    "createdById" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_permissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_live_locations" (
    "userId" UUID NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "accuracy" DOUBLE PRECISION,
    "heading" DOUBLE PRECISION,
    "speed" DOUBLE PRECISION,
    "recordedAt" TIMESTAMPTZ(3) NOT NULL,
    "receivedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "source" TEXT NOT NULL DEFAULT 'GPS',
    "isBackground" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "user_live_locations_pkey" PRIMARY KEY ("userId")
);

-- CreateIndex
CREATE INDEX "product_media_productModelId_sortOrder_idx" ON "product_media"("productModelId", "sortOrder");

-- CreateIndex
CREATE UNIQUE INDEX "user_permissions_userId_permission_key" ON "user_permissions"("userId", "permission");

-- CreateIndex
CREATE INDEX "user_live_locations_recordedAt_idx" ON "user_live_locations"("recordedAt");

-- CreateIndex
CREATE INDEX "product_models_status_sortOrder_idx" ON "product_models"("status", "sortOrder");

-- CreateIndex
CREATE INDEX "users_role_status_idx" ON "users"("role", "status");

-- CreateIndex
CREATE INDEX "worker_profiles_assignedManagerId_idx" ON "worker_profiles"("assignedManagerId");

-- AddForeignKey
ALTER TABLE "worker_profiles" ADD CONSTRAINT "worker_profiles_assignedManagerId_fkey" FOREIGN KEY ("assignedManagerId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_media" ADD CONSTRAINT "product_media_productModelId_fkey" FOREIGN KEY ("productModelId") REFERENCES "product_models"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_media" ADD CONSTRAINT "product_media_variantId_fkey" FOREIGN KEY ("variantId") REFERENCES "product_variants"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_permissions" ADD CONSTRAINT "user_permissions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_live_locations" ADD CONSTRAINT "user_live_locations_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- ==== hand-written guards (Prisma cannot express these) =================================================================

-- D-028: NOTE the new enum values ('SUPER_ADMIN', 'MANAGER') are NOT used by any statement of this migration (PostgreSQL forbids
-- using a value added in the same transaction). The owner is promoted explicitly, after the migration: `cli:promote-owner`.

-- company contact settings: exactly one row, seeded empty (the owner fills phone/Telegram in the app)
ALTER TABLE "company_contact_settings" ADD CONSTRAINT "company_contact_singleton" CHECK ("id" = 1);
INSERT INTO "company_contact_settings" ("id", "updatedAt") VALUES (1, CURRENT_TIMESTAMP);

-- GPS sanity for the live location
ALTER TABLE "user_live_locations" ADD CONSTRAINT "user_live_locations_range" CHECK (
  "latitude" BETWEEN -90 AND 90 AND "longitude" BETWEEN -180 AND 180
  AND ("accuracy" IS NULL OR "accuracy" >= 0) AND ("speed" IS NULL OR "speed" >= 0)
);

-- a worker's manager must be a user with role MANAGER (checked when the value is written; the service also refuses to demote
-- a manager who still has workers)
CREATE FUNCTION worker_manager_must_be_manager() RETURNS trigger AS $$
BEGIN
  IF NEW."assignedManagerId" IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM users u WHERE u.id = NEW."assignedManagerId" AND u.role = 'MANAGER'
  ) THEN
    RAISE EXCEPTION 'worker manager must be a user with role MANAGER' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER "worker_profiles_manager_role" BEFORE INSERT OR UPDATE OF "assignedManagerId" ON "worker_profiles"
  FOR EACH ROW EXECUTE FUNCTION worker_manager_must_be_manager();

-- an override row names a real permission (kept in sync with packages/shared/src/permissions.ts by a test)
ALTER TABLE "user_permissions" ADD CONSTRAINT "user_permissions_name_shape" CHECK ("permission" ~ '^[A-Z][A-Z_]{2,60}$');
