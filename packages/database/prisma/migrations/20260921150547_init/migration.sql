-- pg_trgm must exist before the trigram GIN indexes (search on names).
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- CreateEnum
CREATE TYPE "Role" AS ENUM ('ADMIN', 'WORKER');

-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('ACTIVE', 'SUSPENDED');

-- CreateEnum
CREATE TYPE "WorkerStatus" AS ENUM ('PENDING_APPROVAL', 'ACTIVE', 'PAUSED', 'REJECTED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "LocationSource" AS ENUM ('TELEGRAM', 'APP');

-- CreateEnum
CREATE TYPE "CollateralType" AS ENUM ('MONEY', 'ITEM');

-- CreateEnum
CREATE TYPE "CollateralStatus" AS ENUM ('PENDING', 'HELD', 'RETURNED');

-- CreateEnum
CREATE TYPE "CollateralHistoryType" AS ENUM ('DECLARED', 'PHOTO_ADDED', 'RECEIVED', 'RETURNED', 'NOTE');

-- CreateEnum
CREATE TYPE "MaterialUnit" AS ENUM ('METER', 'GRAM', 'PCS', 'SET', 'ROLL', 'PACKAGE');

-- CreateEnum
CREATE TYPE "StockMovementType" AS ENUM ('RECEIPT', 'ISSUE_TO_KIT', 'ISSUE_TO_WORKER', 'RETURN_FROM_WORKER', 'CONSUMPTION', 'ADJUSTMENT_IN', 'ADJUSTMENT_OUT', 'WRITE_OFF');

-- CreateEnum
CREATE TYPE "AssignmentStatus" AS ENUM ('DRAFT', 'READY_TO_DELIVER', 'DELIVERED', 'IN_PROGRESS', 'READY_FOR_PICKUP', 'PICKED_UP', 'UNDER_REVIEW', 'PARTIALLY_ACCEPTED', 'ACCEPTED', 'REWORK_REQUIRED', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "JobRequestStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'FULFILLED');

-- CreateEnum
CREATE TYPE "DeliveryType" AS ENUM ('DELIVERY_TO_WORKER', 'PICKUP_FROM_WORKER');

-- CreateEnum
CREATE TYPE "DeliveryStatus" AS ENUM ('PENDING', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "QualityResult" AS ENUM ('ACCEPTED', 'PARTIALLY_ACCEPTED', 'REWORK_REQUIRED');

-- CreateEnum
CREATE TYPE "LedgerType" AS ENUM ('EARNING', 'PAYOUT_CASH', 'BONUS', 'CORRECTION');

-- CreateEnum
CREATE TYPE "ExpenseCategory" AS ENUM ('DELIVERY_FUEL', 'PACKAGING', 'OTHER');

-- CreateEnum
CREATE TYPE "QrType" AS ENUM ('ASSIGNMENT', 'WORKER');

-- CreateEnum
CREATE TYPE "NotificationChannel" AS ENUM ('TELEGRAM', 'APP');

-- CreateEnum
CREATE TYPE "NotificationStatus" AS ENUM ('PENDING', 'SENT', 'FAILED');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "phone" TEXT NOT NULL,
    "fullName" TEXT NOT NULL,
    "role" "Role" NOT NULL,
    "status" "UserStatus" NOT NULL DEFAULT 'ACTIVE',
    "passwordHash" TEXT,
    "lastLoginAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_sessions" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "installId" TEXT NOT NULL,
    "deviceName" TEXT,
    "platform" TEXT NOT NULL,
    "appVersion" TEXT,
    "refreshTokenHash" TEXT NOT NULL,
    "previousRefreshTokenHash" TEXT,
    "rotatedAt" TIMESTAMPTZ(3),
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "revokedAt" TIMESTAMPTZ(3),
    "revokedReason" TEXT,
    "ip" TEXT,
    "userAgent" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastUsedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "login_attempts" (
    "id" UUID NOT NULL,
    "phone" TEXT NOT NULL,
    "ip" TEXT,
    "success" BOOLEAN NOT NULL,
    "reason" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "login_attempts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "login_codes" (
    "id" UUID NOT NULL,
    "workerId" UUID NOT NULL,
    "codeHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "usedAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "login_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "worker_profiles" (
    "id" UUID NOT NULL,
    "userId" UUID,
    "telegramUserId" BIGINT NOT NULL,
    "telegramChatId" BIGINT NOT NULL,
    "code" TEXT NOT NULL,
    "fullName" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "secondaryPhone" TEXT,
    "latitude" DECIMAL(9,6),
    "longitude" DECIMAL(9,6),
    "locationReceivedAt" TIMESTAMPTZ(3),
    "status" "WorkerStatus" NOT NULL DEFAULT 'PENDING_APPROVAL',
    "notes" TEXT,
    "approvedAt" TIMESTAMPTZ(3),
    "approvedById" UUID,
    "rejectedReason" TEXT,
    "balance" BIGINT NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "worker_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "worker_locations" (
    "id" UUID NOT NULL,
    "workerId" UUID NOT NULL,
    "latitude" DECIMAL(9,6) NOT NULL,
    "longitude" DECIMAL(9,6) NOT NULL,
    "receivedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "source" "LocationSource" NOT NULL DEFAULT 'TELEGRAM',

    CONSTRAINT "worker_locations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "registration_drafts" (
    "telegramUserId" BIGINT NOT NULL,
    "chatId" BIGINT NOT NULL,
    "state" JSONB NOT NULL,
    "photoFileIds" UUID[],
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "registration_drafts_pkey" PRIMARY KEY ("telegramUserId")
);

-- CreateTable
CREATE TABLE "worker_collaterals" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "workerId" UUID NOT NULL,
    "type" "CollateralType" NOT NULL,
    "amount" BIGINT,
    "description" TEXT,
    "estimatedValue" BIGINT,
    "storageLocation" TEXT,
    "status" "CollateralStatus" NOT NULL DEFAULT 'PENDING',
    "declaredAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "receivedAt" TIMESTAMPTZ(3),
    "receivedById" UUID,
    "returnedAt" TIMESTAMPTZ(3),
    "returnedById" UUID,
    "returnNote" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "worker_collaterals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "collateral_photos" (
    "id" UUID NOT NULL,
    "collateralId" UUID NOT NULL,
    "fileId" UUID NOT NULL,
    "caption" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "collateral_photos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "collateral_history" (
    "id" UUID NOT NULL,
    "collateralId" UUID NOT NULL,
    "type" "CollateralHistoryType" NOT NULL,
    "actorId" UUID,
    "actorLabel" TEXT NOT NULL,
    "note" TEXT,
    "snapshot" JSONB NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "collateral_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "colors" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "hex" TEXT,

    CONSTRAINT "colors_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_models" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "photoFileId" UUID,
    "schemeFileId" UUID,
    "videoFileId" UUID,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "product_models_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_variants" (
    "id" UUID NOT NULL,
    "modelId" UUID NOT NULL,
    "colorId" UUID NOT NULL,
    "sku" TEXT NOT NULL,
    "ratePerMeter" BIGINT NOT NULL,
    "photoFileId" UUID,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "product_variants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "material_categories" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "material_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "materials" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "categoryId" UUID,
    "colorId" UUID,
    "article" TEXT,
    "unit" "MaterialUnit" NOT NULL,
    "minStock" DECIMAL(14,3) NOT NULL DEFAULT 0,
    "unitCost" BIGINT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "materials_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "material_kit_templates" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "variantId" UUID,
    "ribbonMeters" DECIMAL(10,2) NOT NULL DEFAULT 9,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "material_kit_templates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "material_kit_template_items" (
    "id" UUID NOT NULL,
    "templateId" UUID NOT NULL,
    "materialId" UUID NOT NULL,
    "requiredQuantity" DECIMAL(14,3) NOT NULL,

    CONSTRAINT "material_kit_template_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stock_movements" (
    "id" UUID NOT NULL,
    "groupId" UUID NOT NULL,
    "type" "StockMovementType" NOT NULL,
    "materialId" UUID NOT NULL,
    "quantity" DECIMAL(14,3) NOT NULL,
    "warehouseDelta" DECIMAL(14,3) NOT NULL,
    "workerDelta" DECIMAL(14,3) NOT NULL DEFAULT 0,
    "workerId" UUID,
    "assignmentId" UUID,
    "performedById" UUID NOT NULL,
    "comment" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "stock_movements_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stock_balances" (
    "materialId" UUID NOT NULL,
    "quantity" DECIMAL(14,3) NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "stock_balances_pkey" PRIMARY KEY ("materialId")
);

-- CreateTable
CREATE TABLE "work_assignments" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "workerId" UUID NOT NULL,
    "productModelId" UUID NOT NULL,
    "productVariantId" UUID NOT NULL,
    "colorId" UUID NOT NULL,
    "materialKitTemplateId" UUID,
    "jobRequestId" UUID,
    "kitCount" INTEGER NOT NULL,
    "plannedMeters" DECIMAL(10,2) NOT NULL,
    "issuedAt" TIMESTAMPTZ(3),
    "dueAt" TIMESTAMPTZ(3),
    "ratePerMeter" BIGINT NOT NULL,
    "reportedMeters" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "deliveredMeters" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "acceptedMeters" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "defectiveMeters" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "calculatedPayment" BIGINT NOT NULL DEFAULT 0,
    "status" "AssignmentStatus" NOT NULL DEFAULT 'DRAFT',
    "notes" TEXT,
    "createdById" UUID NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "work_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "work_assignment_materials" (
    "id" UUID NOT NULL,
    "assignmentId" UUID NOT NULL,
    "materialId" UUID NOT NULL,
    "quantity" DECIMAL(14,3) NOT NULL,

    CONSTRAINT "work_assignment_materials_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "work_assignment_status_history" (
    "id" UUID NOT NULL,
    "assignmentId" UUID NOT NULL,
    "fromStatus" "AssignmentStatus",
    "toStatus" "AssignmentStatus" NOT NULL,
    "changedById" UUID,
    "actor" TEXT NOT NULL,
    "comment" TEXT,
    "changedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "work_assignment_status_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "work_progress" (
    "id" UUID NOT NULL,
    "assignmentId" UUID NOT NULL,
    "workerId" UUID NOT NULL,
    "reportedMeters" DECIMAL(10,2) NOT NULL,
    "percent" DECIMAL(5,2) NOT NULL,
    "comment" TEXT,
    "clientId" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "work_progress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "worker_job_requests" (
    "id" UUID NOT NULL,
    "workerId" UUID NOT NULL,
    "kitCount" INTEGER NOT NULL,
    "note" TEXT,
    "status" "JobRequestStatus" NOT NULL DEFAULT 'PENDING',
    "decidedById" UUID,
    "decidedAt" TIMESTAMPTZ(3),
    "decisionNote" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "worker_job_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "deliveries" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "workerId" UUID NOT NULL,
    "assignmentId" UUID,
    "type" "DeliveryType" NOT NULL,
    "status" "DeliveryStatus" NOT NULL DEFAULT 'PENDING',
    "notes" TEXT,
    "createdById" UUID NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completedAt" TIMESTAMPTZ(3),
    "completedById" UUID,

    CONSTRAINT "deliveries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "delivery_items" (
    "id" UUID NOT NULL,
    "deliveryId" UUID NOT NULL,
    "materialId" UUID,
    "description" TEXT NOT NULL,
    "quantity" DECIMAL(14,3) NOT NULL,
    "assignmentId" UUID,

    CONSTRAINT "delivery_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "quality_inspections" (
    "id" UUID NOT NULL,
    "assignmentId" UUID NOT NULL,
    "inspectorId" UUID NOT NULL,
    "result" "QualityResult" NOT NULL,
    "broughtMeters" DECIMAL(10,2) NOT NULL,
    "acceptedMeters" DECIMAL(10,2) NOT NULL,
    "defectiveMeters" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "reworkMeters" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "comment" TEXT,
    "photoFileIds" UUID[],
    "inspectedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "quality_inspections_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "qr_entities" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "type" "QrType" NOT NULL,
    "assignmentId" UUID,
    "workerId" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" TIMESTAMPTZ(3),

    CONSTRAINT "qr_entities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "worker_ledger_transactions" (
    "id" UUID NOT NULL,
    "workerId" UUID NOT NULL,
    "assignmentId" UUID,
    "type" "LedgerType" NOT NULL,
    "amount" BIGINT NOT NULL,
    "balanceAfter" BIGINT NOT NULL,
    "cashPaymentId" UUID,
    "reversalOfId" UUID,
    "comment" TEXT,
    "idempotencyKey" TEXT,
    "createdById" UUID NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "worker_ledger_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cash_payments" (
    "id" UUID NOT NULL,
    "workerId" UUID NOT NULL,
    "amount" BIGINT NOT NULL,
    "comment" TEXT,
    "forced" BOOLEAN NOT NULL DEFAULT false,
    "paidById" UUID NOT NULL,
    "paidAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cash_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sales" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "date" TIMESTAMPTZ(3) NOT NULL,
    "customer" TEXT,
    "total" BIGINT NOT NULL,
    "notes" TEXT,
    "createdById" UUID NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sales_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sale_items" (
    "id" UUID NOT NULL,
    "saleId" UUID NOT NULL,
    "productModelId" UUID,
    "variantId" UUID,
    "description" TEXT NOT NULL,
    "quantity" DECIMAL(14,3) NOT NULL,
    "unitPrice" BIGINT NOT NULL,
    "totalPrice" BIGINT NOT NULL,

    CONSTRAINT "sale_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "expenses" (
    "id" UUID NOT NULL,
    "category" "ExpenseCategory" NOT NULL,
    "amount" BIGINT NOT NULL,
    "date" TIMESTAMPTZ(3) NOT NULL,
    "comment" TEXT,
    "createdById" UUID NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "expenses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL,
    "channel" "NotificationChannel" NOT NULL,
    "status" "NotificationStatus" NOT NULL DEFAULT 'PENDING',
    "workerId" UUID,
    "telegramChatId" BIGINT,
    "type" TEXT NOT NULL,
    "body" TEXT,
    "data" JSONB,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "nextAttemptAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastError" TEXT,
    "sentAt" TIMESTAMPTZ(3),
    "readAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL,
    "actorId" UUID,
    "actorRole" TEXT,
    "action" TEXT NOT NULL,
    "entity" TEXT NOT NULL,
    "entityId" UUID,
    "before" JSONB,
    "after" JSONB,
    "ip" TEXT,
    "device" TEXT,
    "requestId" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "file_assets" (
    "id" UUID NOT NULL,
    "bucket" TEXT NOT NULL,
    "objectKey" TEXT NOT NULL,
    "thumbKey" TEXT,
    "mimeType" TEXT NOT NULL,
    "size" BIGINT NOT NULL,
    "sha256" TEXT NOT NULL,
    "width" INTEGER,
    "height" INTEGER,
    "originalName" TEXT,
    "uploadedById" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "file_assets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "idempotency_keys" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "method" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "requestHash" TEXT NOT NULL,
    "statusCode" INTEGER,
    "responseBody" JSONB,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "idempotency_keys_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sequences" (
    "key" TEXT NOT NULL,
    "value" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "sequences_pkey" PRIMARY KEY ("key")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_phone_key" ON "users"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "user_sessions_refreshTokenHash_key" ON "user_sessions"("refreshTokenHash");

-- CreateIndex
CREATE INDEX "user_sessions_userId_revokedAt_idx" ON "user_sessions"("userId", "revokedAt");

-- CreateIndex
CREATE INDEX "user_sessions_previousRefreshTokenHash_idx" ON "user_sessions"("previousRefreshTokenHash");

-- CreateIndex
CREATE INDEX "login_attempts_phone_createdAt_idx" ON "login_attempts"("phone", "createdAt");

-- CreateIndex
CREATE INDEX "login_attempts_ip_createdAt_idx" ON "login_attempts"("ip", "createdAt");

-- CreateIndex
CREATE INDEX "login_codes_workerId_createdAt_idx" ON "login_codes"("workerId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "worker_profiles_userId_key" ON "worker_profiles"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "worker_profiles_telegramUserId_key" ON "worker_profiles"("telegramUserId");

-- CreateIndex
CREATE UNIQUE INDEX "worker_profiles_code_key" ON "worker_profiles"("code");

-- CreateIndex
CREATE UNIQUE INDEX "worker_profiles_phone_key" ON "worker_profiles"("phone");

-- CreateIndex
CREATE INDEX "worker_profiles_status_idx" ON "worker_profiles"("status");

-- CreateIndex
CREATE INDEX "worker_profiles_updatedAt_idx" ON "worker_profiles"("updatedAt");

-- CreateIndex
CREATE INDEX "worker_profiles_fullName_trgm" ON "worker_profiles" USING GIN ("fullName" gin_trgm_ops);

-- CreateIndex
CREATE INDEX "worker_locations_workerId_receivedAt_idx" ON "worker_locations"("workerId", "receivedAt");

-- CreateIndex
CREATE UNIQUE INDEX "worker_collaterals_code_key" ON "worker_collaterals"("code");

-- CreateIndex
CREATE INDEX "worker_collaterals_workerId_idx" ON "worker_collaterals"("workerId");

-- CreateIndex
CREATE INDEX "worker_collaterals_status_idx" ON "worker_collaterals"("status");

-- CreateIndex
CREATE INDEX "collateral_photos_collateralId_idx" ON "collateral_photos"("collateralId");

-- CreateIndex
CREATE INDEX "collateral_history_collateralId_createdAt_idx" ON "collateral_history"("collateralId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "colors_name_key" ON "colors"("name");

-- CreateIndex
CREATE UNIQUE INDEX "product_models_code_key" ON "product_models"("code");

-- CreateIndex
CREATE UNIQUE INDEX "product_variants_sku_key" ON "product_variants"("sku");

-- CreateIndex
CREATE UNIQUE INDEX "product_variants_modelId_colorId_key" ON "product_variants"("modelId", "colorId");

-- CreateIndex
CREATE UNIQUE INDEX "material_categories_name_key" ON "material_categories"("name");

-- CreateIndex
CREATE INDEX "materials_name_trgm" ON "materials" USING GIN ("name" gin_trgm_ops);

-- CreateIndex
CREATE UNIQUE INDEX "material_kit_templates_name_key" ON "material_kit_templates"("name");

-- CreateIndex
CREATE UNIQUE INDEX "material_kit_template_items_templateId_materialId_key" ON "material_kit_template_items"("templateId", "materialId");

-- CreateIndex
CREATE INDEX "stock_movements_materialId_createdAt_idx" ON "stock_movements"("materialId", "createdAt");

-- CreateIndex
CREATE INDEX "stock_movements_workerId_idx" ON "stock_movements"("workerId");

-- CreateIndex
CREATE INDEX "stock_movements_assignmentId_idx" ON "stock_movements"("assignmentId");

-- CreateIndex
CREATE UNIQUE INDEX "work_assignments_code_key" ON "work_assignments"("code");

-- CreateIndex
CREATE UNIQUE INDEX "work_assignments_jobRequestId_key" ON "work_assignments"("jobRequestId");

-- CreateIndex
CREATE INDEX "work_assignments_workerId_status_idx" ON "work_assignments"("workerId", "status");

-- CreateIndex
CREATE INDEX "work_assignments_status_idx" ON "work_assignments"("status");

-- CreateIndex
CREATE INDEX "work_assignments_dueAt_idx" ON "work_assignments"("dueAt");

-- CreateIndex
CREATE INDEX "work_assignment_materials_assignmentId_idx" ON "work_assignment_materials"("assignmentId");

-- CreateIndex
CREATE INDEX "work_assignment_status_history_assignmentId_changedAt_idx" ON "work_assignment_status_history"("assignmentId", "changedAt");

-- CreateIndex
CREATE INDEX "work_progress_assignmentId_createdAt_idx" ON "work_progress"("assignmentId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "work_progress_assignmentId_clientId_key" ON "work_progress"("assignmentId", "clientId");

-- CreateIndex
CREATE INDEX "worker_job_requests_status_idx" ON "worker_job_requests"("status");

-- CreateIndex
CREATE INDEX "worker_job_requests_workerId_idx" ON "worker_job_requests"("workerId");

-- CreateIndex
CREATE UNIQUE INDEX "deliveries_code_key" ON "deliveries"("code");

-- CreateIndex
CREATE INDEX "deliveries_status_type_idx" ON "deliveries"("status", "type");

-- CreateIndex
CREATE INDEX "deliveries_workerId_idx" ON "deliveries"("workerId");

-- CreateIndex
CREATE INDEX "delivery_items_deliveryId_idx" ON "delivery_items"("deliveryId");

-- CreateIndex
CREATE INDEX "quality_inspections_assignmentId_idx" ON "quality_inspections"("assignmentId");

-- CreateIndex
CREATE UNIQUE INDEX "qr_entities_code_key" ON "qr_entities"("code");

-- CreateIndex
CREATE INDEX "qr_entities_assignmentId_idx" ON "qr_entities"("assignmentId");

-- CreateIndex
CREATE INDEX "qr_entities_workerId_idx" ON "qr_entities"("workerId");

-- CreateIndex
CREATE UNIQUE INDEX "worker_ledger_transactions_cashPaymentId_key" ON "worker_ledger_transactions"("cashPaymentId");

-- CreateIndex
CREATE UNIQUE INDEX "worker_ledger_transactions_reversalOfId_key" ON "worker_ledger_transactions"("reversalOfId");

-- CreateIndex
CREATE UNIQUE INDEX "worker_ledger_transactions_idempotencyKey_key" ON "worker_ledger_transactions"("idempotencyKey");

-- CreateIndex
CREATE INDEX "worker_ledger_transactions_workerId_createdAt_idx" ON "worker_ledger_transactions"("workerId", "createdAt");

-- CreateIndex
CREATE INDEX "cash_payments_workerId_paidAt_idx" ON "cash_payments"("workerId", "paidAt");

-- CreateIndex
CREATE UNIQUE INDEX "sales_code_key" ON "sales"("code");

-- CreateIndex
CREATE INDEX "sales_date_idx" ON "sales"("date");

-- CreateIndex
CREATE INDEX "sale_items_saleId_idx" ON "sale_items"("saleId");

-- CreateIndex
CREATE INDEX "expenses_date_idx" ON "expenses"("date");

-- CreateIndex
CREATE INDEX "notifications_status_nextAttemptAt_idx" ON "notifications"("status", "nextAttemptAt");

-- CreateIndex
CREATE INDEX "notifications_workerId_createdAt_idx" ON "notifications"("workerId", "createdAt");

-- CreateIndex
CREATE INDEX "audit_logs_entity_entityId_createdAt_idx" ON "audit_logs"("entity", "entityId", "createdAt");

-- CreateIndex
CREATE INDEX "audit_logs_actorId_createdAt_idx" ON "audit_logs"("actorId", "createdAt");

-- CreateIndex
CREATE INDEX "audit_logs_createdAt_idx" ON "audit_logs"("createdAt");

-- CreateIndex
CREATE INDEX "file_assets_sha256_idx" ON "file_assets"("sha256");

-- CreateIndex
CREATE UNIQUE INDEX "file_assets_bucket_objectKey_key" ON "file_assets"("bucket", "objectKey");

-- CreateIndex
CREATE INDEX "idempotency_keys_createdAt_idx" ON "idempotency_keys"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "idempotency_keys_userId_key_key" ON "idempotency_keys"("userId", "key");

-- AddForeignKey
ALTER TABLE "user_sessions" ADD CONSTRAINT "user_sessions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_profiles" ADD CONSTRAINT "worker_profiles_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_locations" ADD CONSTRAINT "worker_locations_workerId_fkey" FOREIGN KEY ("workerId") REFERENCES "worker_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_collaterals" ADD CONSTRAINT "worker_collaterals_workerId_fkey" FOREIGN KEY ("workerId") REFERENCES "worker_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "collateral_photos" ADD CONSTRAINT "collateral_photos_collateralId_fkey" FOREIGN KEY ("collateralId") REFERENCES "worker_collaterals"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "collateral_history" ADD CONSTRAINT "collateral_history_collateralId_fkey" FOREIGN KEY ("collateralId") REFERENCES "worker_collaterals"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_variants" ADD CONSTRAINT "product_variants_modelId_fkey" FOREIGN KEY ("modelId") REFERENCES "product_models"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_variants" ADD CONSTRAINT "product_variants_colorId_fkey" FOREIGN KEY ("colorId") REFERENCES "colors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "materials" ADD CONSTRAINT "materials_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "material_categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "materials" ADD CONSTRAINT "materials_colorId_fkey" FOREIGN KEY ("colorId") REFERENCES "colors"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "material_kit_templates" ADD CONSTRAINT "material_kit_templates_variantId_fkey" FOREIGN KEY ("variantId") REFERENCES "product_variants"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "material_kit_template_items" ADD CONSTRAINT "material_kit_template_items_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "material_kit_templates"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "material_kit_template_items" ADD CONSTRAINT "material_kit_template_items_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_movements" ADD CONSTRAINT "stock_movements_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_balances" ADD CONSTRAINT "stock_balances_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_assignments" ADD CONSTRAINT "work_assignments_workerId_fkey" FOREIGN KEY ("workerId") REFERENCES "worker_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_assignments" ADD CONSTRAINT "work_assignments_productModelId_fkey" FOREIGN KEY ("productModelId") REFERENCES "product_models"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_assignments" ADD CONSTRAINT "work_assignments_productVariantId_fkey" FOREIGN KEY ("productVariantId") REFERENCES "product_variants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_assignments" ADD CONSTRAINT "work_assignments_colorId_fkey" FOREIGN KEY ("colorId") REFERENCES "colors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_assignments" ADD CONSTRAINT "work_assignments_materialKitTemplateId_fkey" FOREIGN KEY ("materialKitTemplateId") REFERENCES "material_kit_templates"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_assignments" ADD CONSTRAINT "work_assignments_jobRequestId_fkey" FOREIGN KEY ("jobRequestId") REFERENCES "worker_job_requests"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_assignment_materials" ADD CONSTRAINT "work_assignment_materials_assignmentId_fkey" FOREIGN KEY ("assignmentId") REFERENCES "work_assignments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_assignment_materials" ADD CONSTRAINT "work_assignment_materials_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_assignment_status_history" ADD CONSTRAINT "work_assignment_status_history_assignmentId_fkey" FOREIGN KEY ("assignmentId") REFERENCES "work_assignments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_progress" ADD CONSTRAINT "work_progress_assignmentId_fkey" FOREIGN KEY ("assignmentId") REFERENCES "work_assignments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_job_requests" ADD CONSTRAINT "worker_job_requests_workerId_fkey" FOREIGN KEY ("workerId") REFERENCES "worker_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "deliveries" ADD CONSTRAINT "deliveries_workerId_fkey" FOREIGN KEY ("workerId") REFERENCES "worker_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "deliveries" ADD CONSTRAINT "deliveries_assignmentId_fkey" FOREIGN KEY ("assignmentId") REFERENCES "work_assignments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "delivery_items" ADD CONSTRAINT "delivery_items_deliveryId_fkey" FOREIGN KEY ("deliveryId") REFERENCES "deliveries"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "delivery_items" ADD CONSTRAINT "delivery_items_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quality_inspections" ADD CONSTRAINT "quality_inspections_assignmentId_fkey" FOREIGN KEY ("assignmentId") REFERENCES "work_assignments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "qr_entities" ADD CONSTRAINT "qr_entities_assignmentId_fkey" FOREIGN KEY ("assignmentId") REFERENCES "work_assignments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "qr_entities" ADD CONSTRAINT "qr_entities_workerId_fkey" FOREIGN KEY ("workerId") REFERENCES "worker_profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_ledger_transactions" ADD CONSTRAINT "worker_ledger_transactions_workerId_fkey" FOREIGN KEY ("workerId") REFERENCES "worker_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_ledger_transactions" ADD CONSTRAINT "worker_ledger_transactions_assignmentId_fkey" FOREIGN KEY ("assignmentId") REFERENCES "work_assignments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_ledger_transactions" ADD CONSTRAINT "worker_ledger_transactions_cashPaymentId_fkey" FOREIGN KEY ("cashPaymentId") REFERENCES "cash_payments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cash_payments" ADD CONSTRAINT "cash_payments_workerId_fkey" FOREIGN KEY ("workerId") REFERENCES "worker_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sale_items" ADD CONSTRAINT "sale_items_saleId_fkey" FOREIGN KEY ("saleId") REFERENCES "sales"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sale_items" ADD CONSTRAINT "sale_items_productModelId_fkey" FOREIGN KEY ("productModelId") REFERENCES "product_models"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sale_items" ADD CONSTRAINT "sale_items_variantId_fkey" FOREIGN KEY ("variantId") REFERENCES "product_variants"("id") ON DELETE SET NULL ON UPDATE CASCADE;
