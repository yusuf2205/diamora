'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState, type ReactNode } from 'react';
import { hasPerm } from '@/lib/types';
import { useAuth } from '@/lib/auth';
import { useLivePanel } from '@/lib/live';
import { Logo } from '@/components/ui';
import { ShoppingBag, Activity, ClipboardList, Gem, LayoutDashboard, Lock, LogOut, Medal, TrendingUp, MapPin, Menu, Package, ScrollText, Settings, Sparkles, UserCog, Users, type LucideIcon, BarChart3 } from 'lucide-react';
import { initials, roleLabel } from '@/lib/format';
import { useChatUnread } from '@/components/chat';
import { HeaderBadges } from '@/components/header-badges';

const NAV: { href: string; label: string; icon: LucideIcon; perms?: string[] }[] = [
  { href: '/dashboard', label: 'Обзор', icon: LayoutDashboard },
  { href: '/workers', label: 'Мастерицы', icon: Sparkles, perms: ['WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED'] },
  { href: '/collaterals', label: 'Залоги', icon: Lock, perms: ['COLLATERAL_VIEW'] },
  { href: '/assignments', label: 'Задания', icon: ClipboardList, perms: ['ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_VIEW_ASSIGNED'] },
  { href: '/catalog', label: 'Каталог', icon: Gem, perms: ['CATALOG_VIEW', 'CATALOG_MANAGE'] },
  { href: '/orders', label: 'Заказы клиентов', icon: ShoppingBag, perms: ['CATALOG_VIEW', 'CATALOG_MANAGE'] },
  { href: '/inventory', label: 'Склад', icon: Package, perms: ['INVENTORY_VIEW', 'INVENTORY_MANAGE'] },
  { href: '/map', label: 'Карта', icon: MapPin, perms: ['MAP_VIEW_ALL', 'MAP_VIEW_ASSIGNED'] },
  { href: '/reports', label: 'Отчёты', icon: BarChart3, perms: ['FINANCE_VIEW_ALL', 'FINANCE_VIEW_ASSIGNED', 'PROFIT_VIEW'] },
  { href: '/rating', label: 'Рейтинг', icon: Medal, perms: ['WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED'] },
  { href: '/finance', label: 'Прибыль', icon: TrendingUp, perms: ['PROFIT_VIEW'] },
  { href: '/team', label: 'Команда', icon: Users, perms: ['USER_VIEW_ALL'] },
  { href: '/managers', label: 'Менеджеры', icon: UserCog, perms: ['USER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED'] },
  { href: '/settings', label: 'Настройки', icon: Settings, perms: ['PAY_RATE_MANAGE', 'SETTINGS_MANAGE'] },
  { href: '/audit', label: 'Журнал', icon: ScrollText, perms: ['AUDIT_VIEW'] },
  { href: '/system', label: 'Система', icon: Activity, perms: ['SETTINGS_MANAGE'] },
];

/** Everything under (app) requires a signed-in STAFF session (D-028) - the server enforces the rest per page. */
export default function AppLayout({ children }: { children: ReactNode }) {
  const { me, isLoading, signedIn, logout } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const [menuOpen, setMenuOpen] = useState(false);
  useLivePanel(!!me && me.role !== 'WORKER'); // presence («в сети»), live refresh and the web user's own map dot
  const unread = useChatUnread(!!me && me.role !== 'WORKER');
  useEffect(() => setMenuOpen(false), [pathname]); // a tap on a menu item closes the phone drawer

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

  const current = pathname.startsWith('/chat') ? 'Чат' : items.find((n) => pathname.startsWith(n.href))?.label ?? 'Diamoraa';

  // Desktop: a fixed sidebar. Phone / portrait tablet (< lg): a slim top bar with the page name and a ☰ button; the same menu slides in
  // over the page, so the content always gets the full screen width.
  return (
    <div className="min-h-screen lg:flex lg:h-screen lg:overflow-hidden">
      <header className="sticky top-0 z-30 flex items-center gap-3 border-b border-border bg-card px-4 py-3 lg:hidden">
        <button aria-label="Меню" onClick={() => setMenuOpen(true)} className="-ml-1 rounded-lg p-2 hover:bg-border/50"><Menu size={22} aria-hidden /></button>
        <p className="flex-1 truncate text-base font-semibold">{current}</p>
        <HeaderBadges chatUnread={unread} />
      </header>
      {menuOpen && <div className="fixed inset-0 z-40 bg-black/40 lg:hidden" onClick={() => setMenuOpen(false)} />}
      <aside
        className={`fixed inset-y-0 left-0 z-50 flex w-72 max-w-[85vw] flex-col border-r border-border bg-card px-4 py-6 transition-transform lg:static lg:z-auto lg:h-screen lg:w-64 lg:shrink-0 lg:translate-x-0 ${menuOpen ? 'translate-x-0' : '-translate-x-full'}`}
      >
        <div className="mb-6 flex items-center gap-2 px-2">
          <Logo size={30} />
          <div>
            <p className="text-lg font-semibold leading-tight">Diamoraa</p>
            <p className="text-xs text-muted">Панель управления</p>
          </div>
        </div>
        <div className="mb-4"><HeaderBadges chatUnread={unread} sidebar /></div>
        <nav className="flex-1 space-y-1 overflow-y-auto">
          {items.map((n) => (
            <Link
              key={n.href}
              href={n.href}
              className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition ${pathname.startsWith(n.href) ? 'bg-primary text-white shadow-sm' : 'text-foreground hover:bg-border/50'}`}
            >
              <n.icon size={18} strokeWidth={1.8} aria-hidden />
              <span className="flex-1">{n.label}</span>
            </Link>
          ))}
        </nav>
        <div className="mt-4 border-t border-border pt-4">
          <Link href="/profile" className="flex items-center gap-2 rounded-lg px-2 py-1.5 hover:bg-border/50" title="Мой профиль и пароль">
            <span className="flex h-8 w-8 items-center justify-center rounded-full bg-border text-xs font-semibold">{initials(me.fullName)}</span>
            <div className="min-w-0">
              <p className="truncate text-sm font-medium">{me.fullName}</p>
              <p className="truncate text-xs text-muted">{roleLabel(me.role)}</p>
            </div>
          </Link>
          <button onClick={() => logout()} className="mt-3 flex w-full items-center gap-3 rounded-lg px-3 py-2 text-left text-sm text-muted hover:bg-border/50"><LogOut size={16} aria-hidden />Выйти</button>
        </div>
      </aside>
      <main className="min-w-0 flex-1 overflow-x-hidden px-4 py-5 lg:h-screen lg:overflow-y-auto lg:px-8 lg:py-8">{children}</main>
    </div>
  );
}
