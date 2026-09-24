export const dynamic = 'force-dynamic'; // reads ADMIN_HOST at request time

const BOT = process.env.NEXT_PUBLIC_TELEGRAM_BOT_USERNAME || 'diamora1_bot';

/** diamoraa.uz — the door for WORKERS. Staff use the panel on its own host (ADMIN_HOST); until that host exists the
 * panel is reached from the small link at the bottom, exactly as before. Workers never type a password anywhere. */
export default function Landing() {
  const adminHost = (process.env.ADMIN_HOST ?? '').trim();
  const staffHref = adminHost ? `https://${adminHost}/login` : '/login';
  const steps = [
    ['Напишите нашему боту', 'Откройте Telegram и нажмите «Начать» — бот задаст пару вопросов.'],
    ['Дождитесь одобрения', 'Администратор проверит заявку, бот сразу сообщит решение.'],
    ['Войдите в приложение', 'Установите Diamoraa и нажмите «Войти через Telegram». Пароль не нужен.'],
  ];
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col px-5 py-10">
      <div className="flex flex-1 flex-col justify-center">
        <div className="mb-8 text-center">
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-primary text-3xl text-white" aria-hidden>◆</div>
          <h1 className="text-3xl font-semibold">Diamoraa</h1>
          <p className="mt-2 text-muted">Работа для мастериц: берите заказы, отмечайте прогресс и получайте оплату — всё в одном приложении.</p>
        </div>

        <a
          href={`https://t.me/${BOT}`}
          className="flex min-h-12 items-center justify-center gap-2 rounded-xl bg-primary px-5 py-3 text-base font-semibold text-white transition hover:opacity-90 active:scale-[0.99]"
        >
          ✈ Стать мастерицей или войти через Telegram
        </a>

        <ol className="mt-8 space-y-4">
          {steps.map(([title, text], i) => (
            <li key={title} className="flex gap-3">
              <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-semibold text-primary">{i + 1}</span>
              <span>
                <span className="block font-medium">{title}</span>
                <span className="block text-sm text-muted">{text}</span>
              </span>
            </li>
          ))}
        </ol>
        <p className="mt-6 rounded-xl border border-border bg-card p-4 text-sm text-muted">Файл приложения для Android выдаёт администратор. После установки вход — только через Telegram.</p>
      </div>
      <p className="mt-10 text-center text-xs text-muted">
        <a href={staffHref} className="hover:text-foreground hover:underline">Вход для сотрудников</a>
      </p>
    </main>
  );
}
