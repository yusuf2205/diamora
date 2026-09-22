'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, type ReactNode } from 'react';
import { hasPerm } from '@/lib/types';
import { useAuth } from '@/lib/auth';
import { initials, roleLabel } from '@/lib/format';

const NAV: { href: string; label: string; perms?: string[] }[] = [
  { href: '/dashboard', label: 'Обзор' },
  { href: '/workers', label: 'Мастерицы', perms: ['WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED'] },
  { href: '/catalog', label: 'Каталог', perms: ['CATALOG_VIEW', 'CATALOG_MANAGE'] },
  { href: '/map', label: 'Карта', perms: ['MAP_VIEW_ALL', 'MAP_VIEW_ASSIGNED'] },
  { href: '/team', label: 'Команда', perms: ['USER_VIEW_ALL'] },
  { href: '/managers', label: 'Менеджеры', perms: ['USER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED'] },
  { href: '/settings', label: 'Настройки', perms: ['PAY_RATE_MANAGE', 'SETTINGS_MANAGE'] },
  { href: '/audit', label: 'Журнал', perms: ['AUDIT_VIEW'] },
];

/** Everything under (app) requires a signed-in STAFF session (D-028) - the server enforces the rest per page. */
export default function AppLayout({ children }: { children: ReactNode }) {
  const { me, isLoading, signedIn, logout } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (!isLoading && !signedIn) router.replace('/login');
  }, [isLoading, signedIn, router]);

  if (isLoading || !me) {
    return (
      <div className="flex min-h-screen items-center justify-center text-muted">Загрузка…</div>
    );
  }
  if (me.role === 'WORKER') {
    return (
      <div className="flex min-h-screen items-center justify-center px-4 text-center text-muted">
        Эта панель — для администраторов и менеджеров. Мастерицы работают в мобильном приложении.
      </div>
    );
  }

  const items = NAV.filter((n) => !n.perms || hasPerm(me, ...n.perms));

  return (
    <div className="flex min-h-screen">
      <aside className="flex w-64 shrink-0 flex-col border-r border-border bg-card px-4 py-6">
        <div className="mb-6 px-2">
          <p className="text-lg font-semibold">Yusmus</p>
          <p className="text-xs text-muted">Панель управления</p>
        </div>
        <nav className="flex-1 space-y-1">
          {items.map((n) => (
            <Link
              key={n.href}
              href={n.href}
              className={`block rounded-lg px-3 py-2 text-sm font-medium transition ${pathname.startsWith(n.href) ? 'bg-primary text-white' : 'text-foreground hover:bg-border/50'}`}
            >
              {n.label}
            </Link>
          ))}
        </nav>
        <div className="mt-4 border-t border-border pt-4">
          <div className="flex items-center gap-2 px-2">
            <span className="flex h-8 w-8 items-center justify-center rounded-full bg-border text-xs font-semibold">{initials(me.fullName)}</span>
            <div className="min-w-0">
              <p className="truncate text-sm font-medium">{me.fullName}</p>
              <p className="truncate text-xs text-muted">{roleLabel(me.role)}</p>
            </div>
          </div>
          <button onClick={() => logout()} className="mt-3 w-full rounded-lg px-3 py-2 text-left text-sm text-muted hover:bg-border/50">Выйти</button>
        </div>
      </aside>
      <main className="flex-1 overflow-y-auto px-8 py-8">{children}</main>
    </div>
  );
}
