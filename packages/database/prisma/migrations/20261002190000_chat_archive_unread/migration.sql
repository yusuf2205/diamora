-- «Архивировать» and «Пометить как непрочитанное» in the chat list (per person).
ALTER TABLE "chat_members" ADD COLUMN "archivedAt" TIMESTAMPTZ(3);
ALTER TABLE "chat_members" ADD COLUMN "markedUnread" BOOLEAN NOT NULL DEFAULT false;
