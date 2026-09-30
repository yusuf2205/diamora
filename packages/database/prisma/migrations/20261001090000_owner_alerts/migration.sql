-- Owner alerts in Telegram: a staff member links the chat that gets «сервер не отвечает / снова работает / мало места».
ALTER TABLE "users" ADD COLUMN "alertChatId" BIGINT;
