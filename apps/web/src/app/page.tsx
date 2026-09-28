import { Download, Gem, Send, ShieldCheck, Smartphone, Wallet } from 'lucide-react';
import { Logo } from '@/components/ui';

export const dynamic = 'force-dynamic'; // reads ADMIN_HOST at request time

const BOT = process.env.NEXT_PUBLIC_TELEGRAM_BOT_USERNAME || 'diamora1_bot';

/**
 * diamoraa.uz — the door for WORKERS: download the app, install, sign in with Telegram. Three steps, no passwords,
 * big buttons. Staff use the panel on its own host (ADMIN_HOST).
 */
export default function Landing() {
  const adminHost = (process.env.ADMIN_HOST ?? '').trim();
  const staffHref = adminHost ? `https://${adminHost}/login` : '/login';
  const steps = [
    { icon: Download, title: 'Скачайте приложение', text: 'Нажмите большую кнопку ниже — файл скачается за минуту.' },
    { icon: Smartphone, title: 'Установите', text: 'Откройте скачанный файл и нажмите «Установить». Если телефон спросит — разрешите установку.' },
    { icon: Send, title: 'Войдите через Telegram', text: 'В приложении нажмите «Войти через Telegram». Бот задаст 4 коротких вопроса — и всё.' },
  ];
  const perks = [
    { icon: Gem, text: 'Красивые заказы рядом с домом' },
    { icon: Wallet, text: 'Оплата за каждые 9 метров — сразу видно, сколько заработали' },
    { icon: ShieldCheck, text: 'Без паролей: вход через ваш Telegram' },
  ];
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col px-5 pb-8 pt-10">
      <div className="text-center">
        <Logo size={76} className="mx-auto mb-3" />
        <h1 className="text-3xl font-extrabold tracking-tight">Diamoraa</h1>
        <p className="mt-2 text-base text-muted">Работа для мастериц: берите заказы, отмечайте прогресс и получайте оплату — всё в одном приложении.</p>
      </div>

      <a
        href="/download"
        className="mt-8 flex min-h-14 items-center justify-center gap-3 rounded-2xl bg-primary px-5 py-4 text-lg font-bold text-white shadow-lg shadow-primary/25 transition hover:opacity-95 active:scale-[0.99]"
      >
        <Download size={24} aria-hidden /> Скачать приложение
      </a>
      <p className="mt-2 text-center text-xs text-muted">Для Android · бесплатно · <a href="/download/diamoraa-armv7.apk" className="underline">для старых телефонов</a></p>

      <ol className="mt-8 space-y-3">
        {steps.map((s, i) => (
          <li key={s.title} className="flex gap-4 rounded-2xl border border-border bg-card p-4">
            <span className="relative flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
              <s.icon size={22} aria-hidden />
              <span className="absolute -right-1.5 -top-1.5 flex h-5 w-5 items-center justify-center rounded-full bg-primary text-[11px] font-bold text-white">{i + 1}</span>
            </span>
            <span>
              <span className="block font-semibold">{s.title}</span>
              <span className="block text-sm text-muted">{s.text}</span>
            </span>
          </li>
        ))}
      </ol>

      <ul className="mt-6 space-y-2">
        {perks.map((p) => (
          <li key={p.text} className="flex items-center gap-3 text-sm"><p.icon size={18} className="shrink-0 text-primary" aria-hidden />{p.text}</li>
        ))}
      </ul>

      <a
        href={`https://t.me/${BOT}`}
        className="mt-8 flex min-h-12 items-center justify-center gap-2 rounded-2xl border border-border bg-card px-5 py-3 text-base font-semibold transition hover:bg-border/40"
      >
        <Send size={18} aria-hidden /> Уже установили? Открыть бота в Telegram
      </a>

      <p className="mt-auto pt-10 text-center text-xs text-muted">
        <a href={staffHref} className="hover:text-foreground hover:underline">Вход для сотрудников</a>
      </p>
    </main>
  );
}
