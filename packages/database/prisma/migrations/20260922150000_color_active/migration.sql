-- M3 prep: close the Colors/Variants technical debt (§4). Colors already existed and were already referenced by
-- ProductVariant/Material/WorkAssignment; this just adds the missing active flag + timestamps so Colors can have a
-- real admin CRUD lifecycle (list/create/update/deactivate), matching Material's existing pattern. Additive only.
ALTER TABLE "colors"
  ADD COLUMN "isActive" BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN "updatedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
