'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Bell, QrCode, Sparkles } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';
import { api } from '@/lib/api';
import { formatUzs } from '@/lib/format';
import { Button, Card, ErrorState, Input, ListSkeleton, Modal } from '@/components/ui';

interface Work {
  id: string; status: string; kitCount: number; plannedMeters: number; reportedMeters: number; expectedPayment: string | null; dueAt: string | null;
  product: { name: string } | null; color: { name: string; hex: string | null } | null;
  materials: { materialId: string; name: string | null; unit: string | null; quantity: number }[];
  handoff: { status: string; expired: boolean } | null;
}
interface Ledger { balance: string; earned: string; paid: string }
interface Req { id: string; status: string; meters: number; product: { name: string } | null; color: { name: string } | null; decisionNote: string | null; createdAt: string }
interface Notice { id: string; title: string; body: string | null; read: boolean; createdAt: string }

const unit = (u: string | null) => (u === 'METER' ? 'м' : u === 'GRAM' ? 'г' : 'шт');
const day = (iso: string) => new Date(iso).toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit' });
const MONTHS = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];

/** Her home, like the app: the two big actions, her request, the current work, money, notifications. */
export default function WorkerHome() {
  const qc = useQueryClient();
  const work = useQuery<Work | Record<string, never>>({ queryKey: ['w-work'], queryFn: () => api.get('/work/current') });
  const ledger = useQuery<Ledger>({ queryKey: ['w-ledger'], queryFn: () => api.get('/work/earnings') });
  const months = useQuery<{ items: { month: string; acceptedMeters: number; earned: string }[] }>({ queryKey: ['w-months'], queryFn: () => api.get('/work/earnings/monthly') });
  const reqs = useQuery<{ items: Req[] }>({ queryKey: ['w-reqs'], queryFn: () => api.get('/work/requests') });
  const notices = useQuery<{ unread: number; items: Notice[] }>({ queryKey: ['w-notices'], queryFn: () => api.get('/me/notifications') });
  const [showNotices, setShowNotices] = useState(false);
  const cancelReq = useMutation({ mutationFn: (id: string) => api.post(`/work/requests/${id}/cancel`, undefined, { idempotencyKey: crypto.randomUUID() }), onSuccess: () => qc.invalidateQueries({ queryKey: ['w-reqs'] }) });

  const w = work.data && 'id' in work.data ? (work.data as Work) : null;
  const latest = reqs.data?.items[0];
  const showReq = latest && (latest.status === 'PENDING' || (latest.status === 'REJECTED' && Date.now() - new Date(latest.createdAt).getTime() < 3 * 86_400_000));

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-extrabold">Главная</h1>
        <button aria-label="Уведомления" className="relative p-2" onClick={() => setShowNotices(true)}>
          <Bell size={24} />
          {!!notices.data?.unread && <span className="absolute right-0 top-0 rounded-full bg-danger px-1.5 text-xs font-bold text-white">{notices.data.unread}</span>}
        </button>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <Link href="/w/catalog" className="flex h-24 flex-col items-center justify-center gap-1 rounded-2xl bg-primary text-center font-extrabold text-white">
          <Sparkles size={28} aria-hidden /> Выбрать работу
        </Link>
        <Link href="/w/scan" className="flex h-24 flex-col items-center justify-center gap-1 rounded-2xl bg-primary/15 text-center font-extrabold text-primary">
          <QrCode size={28} aria-hidden /> Сканировать QR
        </Link>
      </div>

      {showReq && latest && (
        <Card>
          <p className="font-bold">{latest.status === 'PENDING' ? 'Заявка отправлена' : 'Заявка не принята'}</p>
          <p className="text-sm">{[latest.product?.name, latest.color?.name].filter(Boolean).join(' · ')} · {latest.meters} м</p>
          <p className="text-xs text-muted">{latest.status === 'PENDING' ? 'Ждём ответа менеджера' : latest.decisionNote}</p>
          {latest.status === 'PENDING' && <Button variant="ghost" className="mt-1" onClick={() => cancelReq.mutate(latest.id)}>Отменить заявку</Button>}
        </Card>
      )}

      <section>
        <h2 className="mb-2 font-semibold">Текущая работа</h2>
        {work.isLoading ? <ListSkeleton rows={1} /> : work.error ? <ErrorState error={work.error} /> : w ? <CurrentWork w={w} /> : (
          <Card><p className="text-sm text-muted">Сейчас у вас нет работы. Нажмите «Выбрать работу».</p></Card>
        )}
      </section>

      {ledger.data && (
        <Card>
          <p className="text-xs text-muted">К получению</p>
          <p className="text-2xl font-extrabold">{formatUzs(ledger.data.balance)}</p>
          <div className="mt-2 grid grid-cols-2 text-sm">
            <span>Заработано: <b>{formatUzs(ledger.data.earned)}</b></span>
            <span>Выплачено: <b>{formatUzs(ledger.data.paid)}</b></span>
          </div>
        </Card>
      )}

      {months.data && months.data.items.some((m) => m.acceptedMeters > 0 || m.earned !== '0') && (
        <Card>
          <h2 className="mb-2 font-semibold">Мои заработки по месяцам</h2>
          {months.data.items.map((m) => (
            <div key={m.month} className="flex justify-between py-1 text-sm">
              <span className="w-24 font-semibold">{MONTHS[Number(m.month.slice(5)) - 1]}</span>
              <span className="flex-1">{m.acceptedMeters} м</span>
              <b>{formatUzs(m.earned)}</b>
            </div>
          ))}
        </Card>
      )}

      {showNotices && (
        <Modal title="Уведомления" onClose={() => { setShowNotices(false); api.post('/me/notifications/read', { all: true }).then(() => qc.invalidateQueries({ queryKey: ['w-notices'] })).catch(() => undefined); }}>
          {notices.data?.items.length ? (
            <ul className="divide-y divide-border">
              {notices.data.items.map((n) => (
                <li key={n.id} className="py-2">
                  <p className={n.read ? '' : 'font-bold'}>{n.title}</p>
                  {n.body && <p className="text-sm text-muted">{n.body}</p>}
                  <p className="text-xs text-muted">{new Date(n.createdAt).toLocaleString('ru-RU', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })}</p>
                </li>
              ))}
            </ul>
          ) : <p className="text-sm text-muted">Пока уведомлений нет</p>}
        </Modal>
      )}
    </div>
  );
}

function CurrentWork({ w }: { w: Work }) {
  const qc = useQueryClient();
  const [progress, setProgress] = useState(false);
  const [meters, setMeters] = useState(String(w.reportedMeters || ''));
  const done = () => { qc.invalidateQueries({ queryKey: ['w-work'] }); setProgress(false); };
  const report = useMutation({ mutationFn: () => api.post(`/work/${w.id}/progress`, { reportedMeters: Number(meters).toFixed(2), clientId: crypto.randomUUID() }, { idempotencyKey: crypto.randomUUID() }), onSuccess: done });
  const ready = useMutation({ mutationFn: () => api.post(`/work/${w.id}/ready`, { readyMeters: Number(w.plannedMeters).toFixed(2) }, { idempotencyKey: crypto.randomUUID() }), onSuccess: done });
  const waiting = w.status === 'READY_TO_DELIVER' || w.status === 'DRAFT';
  const kitHere = waiting && w.handoff?.status === 'AWAITING_WORKER' && !w.handoff.expired;
  const pct = w.plannedMeters ? Math.min(100, (w.reportedMeters / w.plannedMeters) * 100) : 0;
  const status: Record<string, string> = { READY_TO_DELIVER: 'Ожидает получения', IN_PROGRESS: 'В работе', READY_FOR_PICKUP: 'Готово — ждём сотрудника', UNDER_REVIEW: 'На проверке', REWORK_REQUIRED: 'Нужна доработка', PARTIALLY_ACCEPTED: 'Принято частично' };

  return (
    <Card>
      {waiting && (
        <div className={`mb-3 rounded-xl p-3 ${kitHere ? 'bg-ok/10' : 'bg-primary/10'}`}>
          <p className="font-bold">{kitHere ? 'Ваш комплект готов к получению' : 'Вас ожидает новая работа'}</p>
          <p className="text-sm">{kitHere ? 'Отсканируйте QR на комплекте, который привёз сотрудник' : 'Сотрудник привезёт комплект и отсканирует QR'}</p>
        </div>
      )}
      <div className="flex items-center gap-2">
        <span className="inline-block h-3 w-3 rounded-full" style={{ background: w.color?.hex ?? '#ccc' }} />
        <p className="font-bold">{w.product?.name}</p>
      </div>
      <p className="text-sm text-muted">{w.color?.name} · {w.plannedMeters} м · комплектов: {w.kitCount}{w.dueAt ? ` · срок ${day(w.dueAt)}` : ''}</p>
      <p className="mt-1 text-xs font-semibold text-primary">{status[w.status] ?? ''}</p>
      {!waiting && (
        <>
          <div className="mt-3 flex justify-between text-sm"><span>Готово {w.reportedMeters} из {w.plannedMeters} м</span><span>{Math.round(pct)}%</span></div>
          <div className="mt-1 h-2 overflow-hidden rounded-full bg-border"><div className="h-full bg-primary" style={{ width: `${pct}%` }} /></div>
        </>
      )}
      {w.expectedPayment && <p className="mt-2 text-sm">Ожидаемая оплата: <b>{formatUzs(w.expectedPayment)}</b></p>}
      {w.materials.length > 0 && <p className="mt-2 text-xs text-muted">{w.materials.map((m) => `${m.name} — ${m.quantity} ${unit(m.unit)}`).join(' · ')}</p>}
      <div className="mt-3 flex flex-col gap-2">
        {kitHere && <Link href="/w/scan" className="rounded-xl bg-primary py-3 text-center font-bold text-white">Сканировать QR</Link>}
        {w.status === 'IN_PROGRESS' && (
          <>
            <Button onClick={() => setProgress(true)}>Обновить прогресс</Button>
            <Button variant="outline" disabled={ready.isPending} onClick={() => { if (confirm(`Вся работа готова (${w.plannedMeters} м)?`)) ready.mutate(); }}>Работа готова</Button>
          </>
        )}
      </div>
      {(report.isError || ready.isError) && <div className="mt-2"><ErrorState error={report.error ?? ready.error} /></div>}
      {progress && (
        <Modal title="Обновить прогресс" onClose={() => setProgress(false)}>
          <p className="mb-2 text-sm text-muted">Сколько метров готово из {w.plannedMeters}?</p>
          <Input type="number" inputMode="decimal" min={0} max={w.plannedMeters} value={meters} onChange={(e) => setMeters(e.target.value)} aria-label="Готово метров" />
          <div className="flex justify-end gap-2 pt-3">
            <Button variant="ghost" onClick={() => setProgress(false)}>Отмена</Button>
            <Button disabled={report.isPending || !(Number(meters) >= 0 && Number(meters) <= w.plannedMeters)} onClick={() => report.mutate()}>Сохранить</Button>
          </div>
        </Modal>
      )}
    </Card>
  );
}
