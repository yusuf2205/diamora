import { NextResponse, type NextRequest } from 'next/server';

/**
 * Three front doors, one app (owner, 2026-09-24 / 2026-10-01):
 *   diamoraa.uz        -> for workers: the landing page (+ the Telegram login fallback page). The panel is not here.
 *   ADMIN_HOST         -> the staff panel (e.g. admin.diamoraa.uz). Its root opens the panel.
 *   SHOP_HOST          -> for customers (e.g. shop.diamoraa.uz): the catalog and «Заказать», nothing else.
 * ADMIN_HOST is a RUNTIME setting: empty = everything stays on one host exactly as before (so nobody is locked out
 * until the subdomain actually exists in Cloudflare). API/sockets never reach this app - Caddy routes them by path.
 */
const WORKER_PATHS = ['/app/auth/telegram', '/w', '/manifest.webmanifest'];

export function proxy(req: NextRequest) {
  const adminHost = (process.env.ADMIN_HOST ?? '').trim().toLowerCase();
  const shopHost = (process.env.SHOP_HOST ?? '').trim().toLowerCase();
  const { pathname, search } = req.nextUrl;
  const host = (req.headers.get('x-forwarded-host') ?? req.headers.get('host') ?? '').split(':')[0].toLowerCase();

  // the customers' shop (owner, 2026-10-01): SHOP_HOST shows only the shop; its root is the catalog
  if (shopHost && host === shopHost) {
    if (pathname === '/') return NextResponse.rewrite(new URL(`/shop${search}`, req.url));
    if (pathname === '/shop' || pathname.startsWith('/shop/')) return NextResponse.next();
    return NextResponse.redirect(new URL('/', req.url));
  }
  // the shop never opens on the workers' or the staff host
  if (shopHost && (pathname === '/shop' || pathname.startsWith('/shop/'))) return NextResponse.redirect(`https://${shopHost}/${search}`);
  const onAdminHost = !adminHost || host === adminHost || host === 'localhost' || host === '127.0.0.1';

  if (!adminHost) return NextResponse.next();

  if (onAdminHost) {
    // the panel's own root goes straight to the panel; the worker landing lives on the main domain
    if (pathname === '/') return NextResponse.redirect(new URL('/dashboard', req.url));
    return NextResponse.next();
  }

  // main domain: the landing and the worker pages stay; anything of the panel moves to its own host
  // exact segment match: '/w' must not swallow the panel's '/workers'
  if (pathname === '/' || WORKER_PATHS.some((p) => pathname === p || pathname.startsWith(`${p}/`))) return NextResponse.next();
  return NextResponse.redirect(`https://${adminHost}${pathname}${search}`);
}

export const config = {
  // pages only: never Next internals, static files or the health probe
  matcher: ['/((?!_next/|api/|favicon|.*\\.(?:png|jpg|jpeg|svg|ico|webp|txt|json|js|css|map)$).*)'],
};
