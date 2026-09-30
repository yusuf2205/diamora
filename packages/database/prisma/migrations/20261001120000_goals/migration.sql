-- «Цель месяца» for workers: a common goal in metres (no money) and an optional personal one.
CREATE TABLE "goal_settings" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "monthlyMeters" INTEGER NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedById" UUID,
    CONSTRAINT "goal_settings_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "goal_settings_single_row" CHECK ("id" = 1),
    CONSTRAINT "goal_settings_meters_nonneg" CHECK ("monthlyMeters" >= 0)
);
INSERT INTO "goal_settings" ("id", "monthlyMeters") VALUES (1, 0);
ALTER TABLE "worker_profiles" ADD COLUMN "monthlyGoalMeters" INTEGER;
ALTER TABLE "worker_profiles" ADD CONSTRAINT "worker_profiles_goal_nonneg" CHECK ("monthlyGoalMeters" IS NULL OR "monthlyGoalMeters" >= 0);
