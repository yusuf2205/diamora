/**
 * WORKER Telegram-only login (§9-10): the bot's handoff button opens this exact URL. On a phone with Diamoraa
 * installed and the App Link verified (assetlinks.json), Android opens the app directly and this page is never
 * rendered. It only renders when that didn't happen — no app installed, verification not done yet, or opened on a
 * desktop — so it is purely a human-readable fallback: the one-time ticket in the URL is never echoed back into the
 * page (§10 — "не выдавать пользователю auth ticket в открытом виде") and this page never calls the API with it.
 */
export default function TelegramHandoffFallbackPage() {
  return (
    <main className="flex min-h-screen items-center justify-center px-4">
      <div className="w-full max-w-sm space-y-4 rounded-xl border border-border bg-card p-6 text-center">
        <h1 className="text-xl font-semibold">Diamoraa</h1>
        <p className="text-sm text-foreground">Установите приложение Diamoraa, чтобы войти.</p>
        <p className="text-sm text-muted">Если приложение уже установлено — откройте эту ссылку ещё раз прямо в Telegram.</p>
        <p className="text-xs text-muted">Файл приложения можно получить у администратора.</p>
      </div>
    </main>
  );
}
