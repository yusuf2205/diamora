'use client';

/**
 * Browser-side API client for the SUPER_ADMIN / ADMIN / MANAGER control panel (§30). Talks to the SAME public origin the
 * Flutter app uses (`NEXT_PUBLIC_API_URL`, = `PUBLIC_URL` in production - Caddy routes `/v1/*` to the API and everything
 * else to this app, D-025). Tokens live in `localStorage` (client-only; this is a staff tool behind a login, same trust
 * model as the mobile app's secure storage) and are refreshed transparently on a 401, exactly like the mobile client.
 */
const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3000';

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public details?: unknown) {
    super(message);
  }
}

const TOKENS_KEY = 'yusmus.tokens';
interface Tokens { accessToken: string; refreshToken: string }

function readTokens(): Tokens | null {
  if (typeof window === 'undefined') return null;
  const raw = window.localStorage.getItem(TOKENS_KEY);
  return raw ? (JSON.parse(raw) as Tokens) : null;
}
function writeTokens(t: Tokens | null) {
  if (typeof window === 'undefined') return;
  if (t) window.localStorage.setItem(TOKENS_KEY, JSON.stringify(t));
  else window.localStorage.removeItem(TOKENS_KEY);
}

let refreshing: Promise<boolean> | null = null;
async function refreshOnce(): Promise<boolean> {
  if (refreshing) return refreshing;
  refreshing = (async () => {
    const tokens = readTokens();
    if (!tokens) return false;
    try {
      const res = await fetch(`${API_BASE}/v1/auth/refresh`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refreshToken: tokens.refreshToken }),
      });
      if (!res.ok) return false;
      const body = (await res.json()) as { accessToken: string; refreshToken: string };
      writeTokens({ accessToken: body.accessToken, refreshToken: body.refreshToken });
      return true;
    } catch {
      return false;
    }
  })();
  try {
    return await refreshing;
  } finally {
    refreshing = null;
  }
}

let onSessionExpired: (() => void) | null = null;
export function setSessionExpiredHandler(fn: (() => void) | null) {
  onSessionExpired = fn;
}

async function request<T>(path: string, init: RequestInit & { skipAuth?: boolean; idempotencyKey?: string } = {}, retried = false): Promise<T> {
  const headers = new Headers(init.headers);
  headers.set('Accept', 'application/json');
  if (init.body && !(init.body instanceof FormData)) headers.set('Content-Type', 'application/json');
  if (init.idempotencyKey) headers.set('Idempotency-Key', init.idempotencyKey);
  if (!init.skipAuth) {
    const tokens = readTokens();
    if (tokens) headers.set('Authorization', `Bearer ${tokens.accessToken}`);
  }
  const res = await fetch(`${API_BASE}/v1${path}`, { ...init, headers });
  if (res.status === 401 && !init.skipAuth && !retried) {
    if (await refreshOnce()) return request<T>(path, init, true);
    writeTokens(null);
    onSessionExpired?.();
  }
  if (!res.ok) {
    let body: { error?: { code?: string; message?: string; details?: unknown } } = {};
    try { body = await res.json(); } catch { /* no body */ }
    throw new ApiError(res.status, body.error?.code ?? 'UNKNOWN', body.error?.message ?? res.statusText, body.error?.details);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

export const api = {
  get: <T>(path: string, query?: Record<string, string | number | undefined>) => {
    const qs = query ? '?' + new URLSearchParams(Object.entries(query).filter(([, v]) => v !== undefined).map(([k, v]) => [k, String(v)])).toString() : '';
    return request<T>(`${path}${qs}`);
  },
  post: <T>(path: string, body?: unknown, opts?: { idempotencyKey?: string; skipAuth?: boolean }) =>
    request<T>(path, { method: 'POST', body: body ? JSON.stringify(body) : undefined, ...opts }),
  put: <T>(path: string, body?: unknown, opts?: { idempotencyKey?: string }) => request<T>(path, { method: 'PUT', body: body ? JSON.stringify(body) : undefined, ...opts }),
  patch: <T>(path: string, body?: unknown) => request<T>(path, { method: 'PATCH', body: body ? JSON.stringify(body) : undefined }),
  delete: <T>(path: string) => request<T>(path, { method: 'DELETE' }),
  upload: <T>(path: string, form: FormData) => request<T>(path, { method: 'POST', body: form }),
};

export function saveTokens(t: Tokens) { writeTokens(t); }
export function clearTokens() { writeTokens(null); }
export function isSignedIn() { return readTokens() !== null; }
