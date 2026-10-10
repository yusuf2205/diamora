-- «Бонус за качество»: the settings (one row), off until the owner switches it on.
CREATE TABLE "quality_bonus_settings" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "enabled" BOOLEAN NOT NULL DEFAULT false,
    "percent" INTEGER NOT NULL DEFAULT 5,
    "maxDefectPercent" INTEGER NOT NULL DEFAULT 0,
    "minMeters" INTEGER NOT NULL DEFAULT 9,
    "enabledAt" TIMESTAMPTZ(3),
    "lastPaidMonth" TEXT,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "updatedById" UUID,
    CONSTRAINT "quality_bonus_settings_pkey" PRIMARY KEY ("id")
);
