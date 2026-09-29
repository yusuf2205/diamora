-- Chat media: a video can carry a preview picture (its first frame, made on the sender's device).
ALTER TABLE "chat_messages" ADD COLUMN "hasThumb" BOOLEAN NOT NULL DEFAULT false;
