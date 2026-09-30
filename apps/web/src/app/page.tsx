import { Download } from 'lucide-react';
import { Logo } from '@/components/ui';

export const dynamic = 'force-dynamic'; // reads ADMIN_HOST at request time

/**
 * diamoraa.uz — the door for WORKERS, as short as possible: one button to download, three one-line steps.
 * Staff use the panel on its own host (ADMIN_HOST).
 */
export default function Landing() {
  const adminHost = (process.env.ADMIN_HOST ?? '').trim();
  const staffHref = adminHost ? `https://${adminHost}/login` : '/login';
  const steps = ['Скачайте приложение', 'Откройте файл и нажмите «Установить»', 'Войдите через Telegram'];
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col px-5 pb-8 pt-14">
      <div className="text-center">
        <Logo size={80} className="mx-auto mb-3" />
        <h1 className="text-3xl font-extrabold tracking-tight">Diamoraa</h1>
        <p className="mt-2 text-base text-muted">Приложение для мастериц</p>
      </div>

      <a
        href="/download"
        className="mt-10 flex min-h-16 items-center justify-center gap-3 rounded-2xl bg-primary px-5 py-4 text-lg font-bold text-white shadow-lg shadow-primary/25 transition hover:opacity-95 active:scale-[0.99]"
      >
        <Download size={26} aria-hidden /> Скачать приложение
      </a>
      <p className="mt-2 text-center text-xs text-muted">
        Android · <a href="/download/diamoraa-armv7.apk" className="underline">для старых телефонов</a>
      </p>
      <a href="/w" className="mt-4 flex min-h-12 items-center justify-center rounded-2xl border border-border bg-card px-5 text-base font-semibold">
        Открыть веб-версию (без установки)
      </a>

      <ol className="mt-10 space-y-3">
        {steps.map((s, i) => (
          <li key={s} className="flex items-center gap-3 text-base">
            <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-bold text-primary">{i + 1}</span>
            {s}
          </li>
        ))}
      </ol>

      <p className="mt-auto pt-12 text-center text-xs text-muted">
        <a href={staffHref} className="hover:text-foreground hover:underline">Вход для сотрудников</a>
      </p>
    </main>
  );
}
