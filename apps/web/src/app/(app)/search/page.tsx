'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { Card, ErrorState, Input, PageHeader } from '@/components/ui';

interface Found {
  workers: { id: string; fullName: string; code: string; phone: string }[];
  works: { id: string; code: string; worker: string; product: string; plannedMeters: number }[];
  orders: { id: string; code: string; name: string; phone: string }[];
  materials: { id: string; name: string }[];
  models: { id: string; name: string; code: string }[];
  staff: { id: string; fullName: string; phone: string }[];
}

/** «Поиск» (owner, 2026-10-11): one line for workers, works, customer orders, materials, models and staff. */
export default function SearchPage() {
  const [q, setQ] = useState('');
  const [debounced, setDebounced] = useState('');
  useEffect(() => { const t = setTimeout(() => setDebounced(q.trim()), 300); return () => clearTimeout(t); }, [q]);
  const found = useQuery<Found>({ queryKey: ['search', debounced], queryFn: () => api.get<Found>('/admin/search', { q: debounced }), enabled: debounced.length >= 2 });
  const d = found.data;
  const sections: { title: string; rows: { key: string; href: string; title: string; sub: string }[] }[] = d ? [
    { title: 'Мастерицы', rows: d.workers.map((x) => ({ key: x.id, href: `/workers/${x.id}`, title: x.fullName, sub: `${x.code} · ${x.phone}` })) },
    { title: 'Работы', rows: d.works.map((x) => ({ key: x.id, href: `/assignments/${x.id}`, title: `${x.worker} · ${x.product}`, sub: `${x.code} · ${x.plannedMeters} м` })) },
    { title: 'Заказы клиентов', rows: d.orders.map((x) => ({ key: x.id, href: '/orders', title: x.name, sub: `${x.code} · ${x.phone}` })) },
    { title: 'Материалы', rows: d.materials.map((x) => ({ key: x.id, href: '/inventory', title: x.name, sub: '' })) },
    { title: 'Каталог', rows: d.models.map((x) => ({ key: x.id, href: `/catalog/${x.id}`, title: x.name, sub: x.code })) },
    { title: 'Сотрудники', rows: d.staff.map((x) => ({ key: x.id, href: `/team/${x.id}`, title: x.fullName, sub: x.phone })) },
  ].filter((s) => s.rows.length > 0) : [];
  return (
    <div className="max-w-2xl space-y-4">
      <PageHeader title="Поиск" subtitle="Мастерицы, работы, заказы, материалы, модели и сотрудники — по имени, телефону или коду." />
      <Input autoFocus placeholder="Например: Малика, +99890…, A-0012" value={q} onChange={(e) => setQ(e.target.value)} />
      {found.error && <ErrorState error={found.error} />}
      {found.isFetching && <p className="text-sm text-muted">Ищем…</p>}
      {d && sections.length === 0 && <p className="text-sm text-muted">Ничего не найдено</p>}
      {sections.map((s) => (
        <Card key={s.title} className="space-y-1">
          <h2 className="text-sm font-semibold text-primary">{s.title}</h2>
          {s.rows.map((r) => (
            <Link key={r.key} href={r.href} className="block rounded-lg px-2 py-1.5 hover:bg-border/40">
              <span className="font-medium">{r.title}</span>
              {r.sub && <span className="block text-sm text-muted">{r.sub}</span>}
            </Link>
          ))}
        </Card>
      ))}
    </div>
  );
}
