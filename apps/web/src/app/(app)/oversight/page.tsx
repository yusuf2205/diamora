'use client';

import { Suspense } from 'react';
import { ChatApp } from '@/components/chat';
import { Spinner } from '@/components/ui';
import { useAuth } from '@/lib/auth';

/** «Все переписки» (SUPER_ADMIN): every conversation of the company, read live, without joining (the server enforces it). */
export default function OversightPage() {
  const { me } = useAuth();
  if (me && me.role !== 'SUPER_ADMIN') return <p className="p-6 text-center text-muted">Этот раздел — только для владельца.</p>;
  return <Suspense fallback={<Spinner />}><ChatApp watch /></Suspense>;
}
