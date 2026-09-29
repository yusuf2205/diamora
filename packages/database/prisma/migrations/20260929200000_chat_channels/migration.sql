-- Chat, stage 4: announcement channels (an audience reads, admins post), group admins, photo / description,
-- «only admins write» for groups.
ALTER TYPE "ChatKind" ADD VALUE 'CHANNEL';
CREATE TYPE "ChatAudience" AS ENUM ('ALL', 'STAFF', 'WORKERS', 'CUSTOM');
ALTER TABLE "chat_rooms" ADD COLUMN "description" TEXT;
ALTER TABLE "chat_rooms" ADD COLUMN "photoFileId" UUID;
ALTER TABLE "chat_rooms" ADD COLUMN "audience" "ChatAudience" NOT NULL DEFAULT 'CUSTOM';
ALTER TABLE "chat_rooms" ADD COLUMN "onlyAdminsWrite" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "chat_members" ADD COLUMN "isAdmin" BOOLEAN NOT NULL DEFAULT false;
