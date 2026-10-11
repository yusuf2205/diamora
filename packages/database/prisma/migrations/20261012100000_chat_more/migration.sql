-- Chat like Telegram (owner, 2026-10-11): «Избранное», polls, location, contact, work cards, round videos,
-- «без звука», link previews, «отправить позже».
ALTER TYPE "ChatKind" ADD VALUE IF NOT EXISTS 'SAVED';
ALTER TYPE "ChatMessageKind" ADD VALUE IF NOT EXISTS 'POLL';
ALTER TYPE "ChatMessageKind" ADD VALUE IF NOT EXISTS 'LOCATION';
ALTER TYPE "ChatMessageKind" ADD VALUE IF NOT EXISTS 'CONTACT';
ALTER TYPE "ChatMessageKind" ADD VALUE IF NOT EXISTS 'CARD';
ALTER TYPE "ChatMessageKind" ADD VALUE IF NOT EXISTS 'VIDEO_NOTE';

ALTER TABLE "chat_messages" ADD COLUMN "data" JSONB;
ALTER TABLE "chat_messages" ADD COLUMN "linkPreview" JSONB;
ALTER TABLE "chat_messages" ADD COLUMN "silent" BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE "chat_poll_votes" (
    "messageId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "option" INTEGER NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "chat_poll_votes_pkey" PRIMARY KEY ("messageId", "userId", "option"),
    CONSTRAINT "chat_poll_votes_messageId_fkey" FOREIGN KEY ("messageId") REFERENCES "chat_messages"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE "chat_scheduled_messages" (
    "id" UUID NOT NULL,
    "roomId" UUID NOT NULL,
    "senderId" UUID NOT NULL,
    "text" TEXT NOT NULL,
    "replyToId" UUID,
    "sendAt" TIMESTAMPTZ(3) NOT NULL,
    "sentAt" TIMESTAMPTZ(3),
    "messageId" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "chat_scheduled_messages_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "chat_scheduled_messages_sentAt_sendAt_idx" ON "chat_scheduled_messages"("sentAt", "sendAt");
CREATE INDEX "chat_scheduled_messages_roomId_senderId_idx" ON "chat_scheduled_messages"("roomId", "senderId");
