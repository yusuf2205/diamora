import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render } from '@testing-library/react';
import type { ReactElement } from 'react';
import { vi } from 'vitest';
import { AuthProvider } from '@/lib/auth';
import { saveTokens } from '@/lib/api';
import type { Me } from '@/lib/types';

/** Routes a mocked `fetch` by pathname (ignoring the query string) — good enough for pages that fire one or two
 * parallel requests (the real shape the API guarantees: `{ ... }` JSON, or `{ error: {...} }` for a failure). */
export function mockFetch(routes: Record<string, unknown>) {
  const fn = vi.fn(async (input: RequestInfo | URL) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    const path = new URL(url).pathname.replace(/^\/v1/, '');
    const match = Object.entries(routes).find(([k]) => path === k || path.startsWith(k));
    if (!match) {
      return new Response(JSON.stringify({ error: { code: 'NOT_FOUND', message: `unmocked path ${path}` } }), { status: 404 });
    }
    return new Response(JSON.stringify(match[1]), { status: 200, headers: { 'Content-Type': 'application/json' } });
  });
  vi.stubGlobal('fetch', fn);
  return fn;
}

/** A signed-in session: tokens in localStorage + `/auth/me` mocked, so `useAuth()` resolves synchronously enough for `waitFor`. */
export function signIn(me: Me) {
  saveTokens({ accessToken: 'test-access', refreshToken: 'test-refresh' });
  return me;
}

export function renderWithProviders(ui: ReactElement) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={qc}><AuthProvider>{ui}</AuthProvider></QueryClientProvider>);
}
