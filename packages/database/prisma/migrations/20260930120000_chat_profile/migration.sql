-- Telegram-like profile and chat tools: a profile photo, «о себе», a username; clear / delete a chat for me;
-- «запретить копирование» per chat; the waveform of a voice message.
ALTER TABLE "users" ADD COLUMN "avatarFileId" UUID;
ALTER TABLE "users" ADD COLUMN "bio" TEXT;
ALTER TABLE "users" ADD COLUMN "username" TEXT;
CREATE UNIQUE INDEX "users_username_key" ON "users"("username");
ALTER TABLE "chat_members" ADD COLUMN "clearedAt" TIMESTAMPTZ(3);
ALTER TABLE "chat_members" ADD COLUMN "hiddenAt" TIMESTAMPTZ(3);
ALTER TABLE "chat_rooms" ADD COLUMN "protectContent" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "chat_messages" ADD COLUMN "waveform" TEXT;
