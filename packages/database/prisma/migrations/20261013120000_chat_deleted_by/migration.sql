-- who deleted a chat message: everyone else stops seeing it, the SUPER_ADMIN sees it with its content and who removed it
ALTER TABLE "chat_messages" ADD COLUMN "deletedById" UUID;
ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_deletedById_fkey" FOREIGN KEY ("deletedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
