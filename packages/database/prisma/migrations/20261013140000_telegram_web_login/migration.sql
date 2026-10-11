-- a Telegram login started in a browser (the web version): the bot tells her to go back to the browser instead of offering the app
ALTER TABLE "telegram_login_sessions" ADD COLUMN "web" BOOLEAN NOT NULL DEFAULT false;
