'use client';

import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { createContext, useCallback, useContext, useEffect, useMemo, type ReactNode } from 'react';
import { api, clearTokens, isSignedIn, saveTokens, setSessionExpiredHandler } from './api';
import type { Me } from './types';

interface AuthContextValue {
  me: Me | undefined;
  isLoading: boolean;
  signedIn: boolean;
  login: (phone: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}
const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const qc = useQueryClient();
  const router = useRouter();

  const meQuery = useQuery<Me>({
    queryKey: ['me'],
    queryFn: () => api.get<Me>('/auth/me'),
    enabled: isSignedIn(),
    retry: false,
    staleTime: 30_000,
  });

  useEffect(() => {
    setSessionExpiredHandler(() => {
      qc.setQueryData(['me'], undefined);
      qc.clear();
      router.replace('/login');
    });
    return () => setSessionExpiredHandler(null);
  }, [qc, router]);

  const login = useCallback(
    async (phone: string, password: string) => {
      const res = await api.post<{ accessToken: string; refreshToken: string; user: Me }>(
        '/auth/admin/login',
        { phone, password, device: { installId: deviceId(), platform: 'WEB', name: 'Web panel' } },
        { skipAuth: true },
      );
      saveTokens({ accessToken: res.accessToken, refreshToken: res.refreshToken });
      qc.setQueryData(['me'], res.user);
      await qc.invalidateQueries({ queryKey: ['me'] });
    },
    [qc],
  );

  const logout = useCallback(async () => {
    try {
      await api.post('/auth/logout');
    } catch {
      /* the token may already be dead; log out locally regardless */
    }
    clearTokens();
    qc.clear();
    router.replace('/login');
  }, [qc, router]);

  const value = useMemo<AuthContextValue>(
    () => ({ me: meQuery.data, isLoading: isSignedIn() && meQuery.isLoading, signedIn: !!meQuery.data, login, logout }),
    [meQuery.data, meQuery.isLoading, login, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>');
  return ctx;
}

/** Stable per-browser id for the "device" the session is bound to (sessions list, D-007). */
function deviceId(): string {
  if (typeof window === 'undefined') return 'server';
  const key = 'yusmus.deviceId';
  let id = window.localStorage.getItem(key);
  if (!id) {
    id = crypto.randomUUID();
    window.localStorage.setItem(key, id);
  }
  return id;
}
