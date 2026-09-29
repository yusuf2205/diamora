-- Chat, stage 2: replies, edits, forwards, reactions, a pinned message per chat, pinned / muted chats per person.
ALTER TABLE "chat_messages" ADD COLUMN "replyToId" UUID;
ALTER TABLE "chat_messages" ADD COLUMN "editedAt" TIMESTAMPTZ(3);
ALTER TABLE "chat_messages" ADD COLUMN "forwardedFrom" TEXT;
ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_replyToId_fkey" FOREIGN KEY ("replyToId") REFERENCES "chat_messages"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "chat_rooms" ADD COLUMN "pinnedMessageId" UUID;
ALTER TABLE "chat_members" ADD COLUMN "pinnedAt" TIMESTAMPTZ(3);
ALTER TABLE "chat_members" ADD COLUMN "mutedUntil" TIMESTAMPTZ(3);

CREATE TABLE "chat_reactions" (
  "messageId" UUID NOT NULL,
  "userId" UUID NOT NULL,
  "emoji" TEXT NOT NULL,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "chat_reactions_pkey" PRIMARY KEY ("messageId", "userId")
);
ALTER TABLE "chat_reactions" ADD CONSTRAINT "chat_reactions_messageId_fkey" FOREIGN KEY ("messageId") REFERENCES "chat_messages"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "chat_reactions" ADD CONSTRAINT "chat_reactions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- search inside my chats (ILIKE '%...%')
CREATE INDEX "chat_messages_text_trgm" ON "chat_messages" USING GIN ("text" gin_trgm_ops);
