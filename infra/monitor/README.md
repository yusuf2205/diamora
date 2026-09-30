# Внешний сторож Diamoraa / Diamoraa outside watchdog

**RU.** Сервер (NAS) не может сам сообщить, что он выключен. Этот сторож работает на Cloudflare (бесплатно), каждые
2 минуты открывает diamoraa.uz и admin.diamoraa.uz и пишет владельцу в Telegram через бота @diamora1_bot:

- 🔴 «Diamoraa не отвечает с 10:00» — после двух неудачных проверок подряд (~4 мин; короткий сбой или обновление не беспокоят);
- 🟢 «Diamoraa снова работает, было недоступно 34 мин».

Сообщения «снова работает» и «заканчивается место» от самого NAS приходят после привязки в панели: **Профиль →
Оповещения в Telegram → Подключить**. Бот ответит «Готово» и пришлёт **номер чата** — он нужен в шаге 4.

## Установка (один раз, ~10 минут)

Нужен вход в тот аккаунт Cloudflare, где домен diamoraa.uz. В терминале, в папке проекта:

1. `cd infra/monitor`
2. `npx wrangler login` — откроется браузер, нажмите «Allow».
3. `npx wrangler kv namespace create STATE` — скопируйте показанный `id` в `wrangler.toml` вместо `PASTE_KV_ID_HERE`.
4. `npx wrangler secret put CHAT_IDS` — вставьте номер чата из ответа бота (несколько — через запятую).
5. `npx wrangler secret put TELEGRAM_BOT_TOKEN` — вставьте токен бота (тот же, что в `.env` на NAS). Токен не хранится в git.
6. `npx wrangler deploy`

Проверка: откройте адрес, который покажет `wrangler deploy` (…workers.dev) — там состояние `{"fails":0,…}`.
Логика проверена тестами: `node --test infra/monitor/logic.test.mjs`.

---

**EN.** A powered-off NAS cannot report itself. This Cloudflare Worker (free plan) checks diamoraa.uz and admin.diamoraa.uz
every 2 minutes and messages the owner through the bot: 🔴 after two failed checks in a row (~4 min), 🟢 when it answers
again (with the down time). State lives in a KV namespace; secrets `TELEGRAM_BOT_TOKEN` and `CHAT_IDS` are set with
`wrangler secret put` and never committed. The NAS itself (worker container) sends «back up after N min» on start and
«disk almost full» once a day to admins who linked their chat (Profile → Telegram alerts). Setup steps are above.
