'use client';

import { Home, MessageCircle, QrCode, Sparkles, User } from 'lucide-react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, type ReactNode } from 'react';
import { isSignedIn } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { useLivePanel } from '@/lib/live';
import { InstallButton } from './install';
import { useChatUnread } from '@/components/chat';

const NAV = [
  { href: '/w', label: 'Главная', icon: Home },
  { href: '/w/catalog', label: 'Работы', icon: Sparkles },
  { href: '/w/scan', label: 'QR', icon: QrCode },
  { href: '/w/chat', label: 'Чат', icon: MessageCircle },
  { href: '/w/profile', label: 'Профиль', icon: User },
];

/**
 * The web version for workers (diamoraa.uz/w): everything the Android app does — sign in with Telegram, see waiting
 * work, scan the kit QR and confirm receipt, progress, «Работа готова», order work, earnings, notifications — in any
 * phone browser, installable to the home screen with one button.
 */
export default function WorkerWebLayout({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { me, isLoading } = useAuth();
  const onLogin = pathname === '/w/login';
  useLivePanel(me?.role === 'WORKER');
  const unread = useChatUnread(me?.role === 'WORKER'); // realtime refresh + her position while the page is open (like the app)

  useEffect(() => {
    if (typeof navigator !== 'undefined' && 'serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').catch(() => undefined);
  }, []);
  useEffect(() => {
    if (!onLogin && !isLoading && !isSignedIn()) router.replace('/w/login');
  }, [onLogin, isLoading, router]);

  if (onLogin) return <div className="mx-auto min-h-screen max-w-md">{children}</div>;
  if (isLoading || !me) return <div className="flex min-h-screen items-center justify-center text-muted">Загрузка…</div>;
  if (me.role !== 'WORKER') {
    return (
      <main className="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center gap-3 px-6 text-center">
        <p className="text-lg font-semibold">Это вход для мастериц</p>
        <Link href="/dashboard" className="text-primary underline">Открыть панель сотрудника</Link>
      </main>
    );
  }

  return (
    <div className="mx-auto flex min-h-screen max-w-md flex-col">
      <InstallButton />
      <main className="flex-1 px-4 pb-24 pt-4">{children}</main>
      <nav className="fixed inset-x-0 bottom-0 z-30 border-t border-border bg-card/95 pb-[env(safe-area-inset-bottom)] backdrop-blur">
        <div className="mx-auto grid max-w-md grid-cols-5">
          {NAV.map((n) => {
            const active = n.href === '/w' ? pathname === '/w' : pathname.startsWith(n.href);
            return (
              <Link key={n.href} href={n.href} className={`relative flex flex-col items-center gap-0.5 py-2 text-xs ${active ? 'font-bold text-primary' : 'text-muted'}`}>
                <n.icon size={22} aria-hidden />
                {n.href === "/w/chat" && unread > 0 && <span className="absolute right-[18%] top-0.5 min-w-5 rounded-full bg-danger px-1.5 text-center text-xs font-bold leading-5 text-white ring-2 ring-card">{unread}</span>}
                {n.label}
              </Link>
            );
          })}
        </div>
      </nav>
    </div>
  );
}
