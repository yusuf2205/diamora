-- Chat: everyone with everyone. DIRECT (two people, one room per pair via directKey), GROUP (members chosen), COMPANY
-- (one room, every active user). Messages are text or one file (photo, video, voice, audio, document) up to 50 MB.
CREATE TYPE "ChatKind" AS ENUM ('DIRECT', 'GROUP', 'COMPANY');
CREATE TYPE "ChatMessageKind" AS ENUM ('TEXT', 'IMAGE', 'VIDEO', 'VOICE', 'AUDIO', 'FILE');

CREATE TABLE "chat_rooms" (
  "id" UUID NOT NULL,
  "kind" "ChatKind" NOT NULL,
  "title" TEXT,
  "directKey" TEXT,
  "createdById" UUID,
  "lastMessageAt" TIMESTAMPTZ(3),
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "chat_rooms_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "chat_rooms_directKey_key" ON "chat_rooms"("directKey");
CREATE INDEX "chat_rooms_kind_idx" ON "chat_rooms"("kind");

CREATE TABLE "chat_members" (
  "roomId" UUID NOT NULL,
  "userId" UUID NOT NULL,
  "isOwner" BOOLEAN NOT NULL DEFAULT false,
  "lastReadAt" TIMESTAMPTZ(3),
  "joinedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "chat_members_pkey" PRIMARY KEY ("roomId", "userId")
);
CREATE INDEX "chat_members_userId_idx" ON "chat_members"("userId");
ALTER TABLE "chat_members" ADD CONSTRAINT "chat_members_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "chat_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "chat_members" ADD CONSTRAINT "chat_members_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "chat_messages" (
  "id" UUID NOT NULL,
  "roomId" UUID NOT NULL,
  "senderId" UUID,
  "kind" "ChatMessageKind" NOT NULL DEFAULT 'TEXT',
  "text" TEXT,
  "fileId" UUID,
  "fileName" TEXT,
  "fileSize" BIGINT,
  "mimeType" TEXT,
  "durationMs" INTEGER,
  "width" INTEGER,
  "height" INTEGER,
  "clientId" TEXT,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deletedAt" TIMESTAMPTZ(3),
  CONSTRAINT "chat_messages_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "chat_messages_roomId_createdAt_idx" ON "chat_messages"("roomId", "createdAt");
CREATE UNIQUE INDEX "chat_messages_senderId_clientId_key" ON "chat_messages"("senderId", "clientId");
ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "chat_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
