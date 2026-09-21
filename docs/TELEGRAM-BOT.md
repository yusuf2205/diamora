# Telegram bot

**Bot = interface. NestJS = business logic. PostgreSQL = truth.**
The bot (`apps/api/src/worker.ts`, container `worker`) uses **long polling** (no public webhook). It converts a Telegram update into a `BotInput` and calls `RegistrationService.process(...)`, then renders the returned `BotReply` (text + keyboard). Conversation state is stored in `registration_drafts`, so a restart never loses progress.

## Registration flow (russian texts in `registration/texts.ts`)

```
/start ─► NAME (ФИО) ─► PHONE (Contact Share button; contact must belong to the sender)
       ─► SECONDARY_PHONE (optional, «Пропустить») ─► LOCATION (Location Share button, exact GPS)
       ─► COLLATERAL_TYPE  [💵 Деньги] [💍 Вещь]
            MONEY → COLLATERAL_AMOUNT (whole UZS)
            ITEM  → COLLATERAL_DESCRIPTION ─► COLLATERAL_PHOTOS (1..10 photos, «Готово»)
       ─► NOTE (optional) ─► CONFIRM (summary) [✅ Подтвердить] [✏️ Изменить]
       ─► SUBMITTED: WorkerProfile(PENDING_APPROVAL) + Collateral(PENDING) + realtime `worker.created` to ADMIN
```
Not asked: worker photo, experience, skills, district, address, landmark (GPS is enough).
`/cancel` resets the draft. `/start` for an existing worker shows her status. Edit returns to the confirmation screen after the changed field.

## Rules
- Photos are downloaded by the bot process and stored in MinIO immediately (the Telegram `file_id` is never used as storage).
- GPS is stored with `receivedAt` and `source = TELEGRAM` in `worker_locations`; the profile keeps the latest point. No hidden tracking: the bot only reads a location the worker deliberately shares. A later location share from a registered worker updates her point (`worker.location.updated`).
- One Telegram account = one worker (`telegramUserId` unique). Phone is unique.
- Notifications to workers (approval, login codes, later: delivery/payment) are rows in `notifications` (channel `TELEGRAM`); the bot process sends them and marks them `SENT/FAILED` (retry with back-off). Login codes are cleared from the row after sending.
- Worker login in the app: phone → API creates a code → bot sends it to her chat → she enters it in the app.

## Setup
1. @BotFather → `/newbot` → token → `TELEGRAM_BOT_TOKEN` in `.env`.
2. `docker compose up -d worker` (the container has outbound internet only through the `egress` network).
