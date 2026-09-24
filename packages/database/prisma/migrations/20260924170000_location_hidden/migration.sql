-- SUPER_ADMIN can hide a person from everybody else's map (the position is still reported and kept)
ALTER TABLE "users" ADD COLUMN "locationHidden" BOOLEAN NOT NULL DEFAULT false;
