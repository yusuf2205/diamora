import { NextResponse, type NextRequest } from 'next/server';

/**
 * Two front doors, one app (owner, 2026-09-24):
 *   diamoraa.uz        -> for workers: the landing page (+ the Telegram login fallback page). The panel is not here.
 *   ADMIN_HOST         -> the staff panel (e.g. admin.diamoraa.uz). Its root opens the panel.
 * ADMIN_HOST is a RUNTIME setting: empty = everything stays on one host exactly as before (so nobody is locked out
 * until the subdomain actually exists in Cloudflare). API/sockets never reach this app - Caddy routes them by path.
 */
const WORKER_PATHS = ['/app/auth/telegram'];

export function proxy(req: NextRequest) {
  const adminHost = (process.env.ADMIN_HOST ?? '').trim().toLowerCase();
  const { pathname, search } = req.nextUrl;
  const host = (req.headers.get('x-forwarded-host') ?? req.headers.get('host') ?? '').split(':')[0].toLowerCase();
  const onAdminHost = !adminHost || host === adminHost || host === 'localhost' || host === '127.0.0.1';

  if (!adminHost) return NextResponse.next();

  if (onAdminHost) {
    // the panel's own root goes straight to the panel; the worker landing lives on the main domain
    if (pathname === '/') return NextResponse.redirect(new URL('/dashboard', req.url));
    return NextResponse.next();
  }

  // main domain: the landing and the worker pages stay; anything of the panel moves to its own host
  if (pathname === '/' || WORKER_PATHS.some((p) => pathname.startsWith(p))) return NextResponse.next();
  return NextResponse.redirect(`https://${adminHost}${pathname}${search}`);
}

export const config = {
  // pages only: never Next internals, static files or the health probe
  matcher: ['/((?!_next/|api/|favicon|.*\\.(?:png|jpg|jpeg|svg|ico|webp|txt|json|js|css|map)$).*)'],
};
