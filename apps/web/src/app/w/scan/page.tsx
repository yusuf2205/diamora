'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { CheckCircle2 } from 'lucide-react';
import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';
import { api, ApiError } from '@/lib/api';
import { formatUzs } from '@/lib/format';
import { Button, Card, Input } from '@/components/ui';

interface Scan {
  handoffId: string; state: 'AWAITING_WORKER' | 'CONFIRMED';
  assignment: { plannedMeters: number; kitCount: number; expectedPayment: string | null; dueAt: string | null; product: { name: string } | null; color: { name: string; hex: string | null } | null; materials: { materialId: string; name: string | null; unit: string | null; quantity: number }[] };
}
const ERR: Record<string, string> = {
  FOREIGN_KIT: 'Этот комплект предназначен другой мастерице.',
  HANDOFF_NOT_STARTED: 'Сначала сотрудник должен отсканировать этот QR',
  HANDOFF_EXPIRED: 'Время передачи истекло. Попросите сотрудника отсканировать QR ещё раз.',
  NOT_FOUND: 'QR-код не найден',
};
const REASONS: [string, string][] = [['SHORTAGE', 'Не хватает материала'], ['WRONG_COLOR', 'Неправильный цвет'], ['WRONG_MODEL', 'Неправильная модель'], ['WRONG_METERS', 'Неправильный метраж'], ['DAMAGED', 'Повреждение'], ['OTHER', 'Другое']];
const unit = (u: string | null) => (u === 'METER' ? 'м' : u === 'GRAM' ? 'г' : 'шт');

/** Receive the kit in a browser: camera QR -> «Получение работы» -> «Подтвердить получение» / «Есть проблема». */
export default function WorkerScan() {
  const qc = useQueryClient();
  const video = useRef<HTMLVideoElement>(null);
  const busy = useRef(false);
  const [scan, setScan] = useState<Scan | null>(null);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [done, setDone] = useState(false);
  const [problem, setProblem] = useState<string | null>(null);
  const [comment, setComment] = useState('');

  useEffect(() => {
    if (scan || done || !video.current) return;
    let scanner: { start: () => Promise<void>; stop: () => void; destroy: () => void } | null = null;
    let alive = true;
    import('qr-scanner').then(({ default: QrScanner }) => {
      if (!alive || !video.current) return;
      scanner = new QrScanner(video.current, async (r: { data: string }) => {
        if (busy.current) return;
        busy.current = true;
        navigator.vibrate?.(80);
        setMsg({ ok: true, text: 'QR распознан' });
        try {
          const s = await api.post<Scan>('/work/handoff/scan', { code: r.data });
          if (s.state === 'CONFIRMED') setMsg({ ok: true, text: 'Вы уже получили эту работу' });
          else { setScan(s); scanner?.stop(); }
        } catch (e) {
          setMsg({ ok: false, text: e instanceof ApiError ? ERR[e.code] ?? e.message : 'Нет связи с сервером' });
        } finally {
          setTimeout(() => { busy.current = false; }, 1500);
        }
      }, { preferredCamera: 'environment', highlightScanRegion: true, maxScansPerSecond: 4 });
      scanner.start().catch(() => setMsg({ ok: false, text: 'Разрешите доступ к камере в браузере' }));
    });
    return () => { alive = false; scanner?.stop(); scanner?.destroy(); };
  }, [scan, done]);

  const confirm = useMutation({
    mutationFn: async () => {
      const pos = await new Promise<GeolocationPosition | null>((res) => navigator.geolocation ? navigator.geolocation.getCurrentPosition(res, () => res(null), { timeout: 4000, maximumAge: 60_000 }) : res(null));
      return api.post(`/work/handoff/${scan!.handoffId}/confirm`, pos ? { latitude: pos.coords.latitude, longitude: pos.coords.longitude, accuracyM: pos.coords.accuracy } : {}, { idempotencyKey: crypto.randomUUID() });
    },
    onSuccess: () => { setDone(true); qc.invalidateQueries({ queryKey: ['w-work'] }); },
    onError: (e) => setMsg({ ok: false, text: e instanceof ApiError ? ERR[e.code] ?? e.message : 'Нет связи с сервером' }),
  });
  const report = useMutation({
    mutationFn: () => api.post(`/work/handoff/${scan!.handoffId}/problem`, { reason: problem, comment: comment.trim() || undefined }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { setScan(null); setProblem(null); setMsg({ ok: true, text: 'Сотрудник получил ваше сообщение. Работа пока не передана.' }); qc.invalidateQueries({ queryKey: ['w-work'] }); },
  });

  if (done) {
    return (
      <div className="flex flex-col items-center gap-3 pt-16 text-center">
        <CheckCircle2 size={88} className="text-ok" />
        <h1 className="text-2xl font-extrabold">Работа получена!</h1>
        <p className="text-muted">Материалы теперь у вас. Удачной работы!</p>
        <Link href="/w" className="mt-4 w-full rounded-xl bg-primary py-3 font-bold text-white">На главную</Link>
      </div>
    );
  }

  if (scan) {
    const a = scan.assignment;
    return (
      <div className="space-y-3">
        <h1 className="text-2xl font-extrabold">Получение работы</h1>
        <Card>
          <div className="flex items-center gap-2"><span className="h-3 w-3 rounded-full" style={{ background: a.color?.hex ?? '#ccc' }} /><p className="font-bold">{a.product?.name}</p></div>
          <p className="text-sm text-muted">{a.color?.name} · {a.plannedMeters} м · комплектов: {a.kitCount}{a.dueAt ? ` · срок ${new Date(a.dueAt).toLocaleDateString('ru-RU')}` : ''}</p>
          {a.expectedPayment && <p className="mt-1 text-sm">Ожидаемая оплата: <b>{formatUzs(a.expectedPayment)}</b></p>}
          <ul className="mt-2 text-sm">{a.materials.map((m) => <li key={m.materialId}>{m.name} — {m.quantity} {unit(m.unit)}</li>)}</ul>
        </Card>
        <p className="rounded-xl bg-primary/10 p-3 text-sm font-semibold">Проверьте работу и материалы перед подтверждением.</p>
        {msg && !msg.ok && <p className="rounded-xl bg-danger/10 p-3 text-sm text-danger">{msg.text}</p>}
        <Button className="w-full py-4 text-lg" disabled={confirm.isPending} onClick={() => confirm.mutate()}>{confirm.isPending ? 'Сохраняем…' : 'Подтвердить получение'}</Button>
        <Button variant="ghost" className="w-full" onClick={() => setProblem('OTHER')}>Есть проблема</Button>
        {problem && (
          <Card>
            <p className="mb-2 font-semibold">Что не так?</p>
            <div className="flex flex-wrap gap-2">{REASONS.map(([k, t]) => <button key={k} onClick={() => setProblem(k)} className={`rounded-full border px-3 py-1 text-sm ${problem === k ? 'border-primary bg-primary/10 font-bold' : 'border-border'}`}>{t}</button>)}</div>
            <Input className="mt-2" placeholder="Комментарий (необязательно)" aria-label="Комментарий" value={comment} onChange={(e) => setComment(e.target.value)} />
            <Button className="mt-2 w-full" disabled={report.isPending} onClick={() => report.mutate()}>Отправить</Button>
          </Card>
        )}
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <h1 className="text-2xl font-extrabold">Сканировать QR</h1>
      <div className="overflow-hidden rounded-2xl bg-black"><video ref={video} className="aspect-square w-full object-cover" muted playsInline /></div>
      <p className={`rounded-xl p-3 text-sm font-semibold ${msg ? (msg.ok ? 'bg-ok/10 text-ok' : 'bg-danger/10 text-danger') : 'bg-primary/10'}`}>{msg?.text ?? 'Наведите камеру на QR-код комплекта'}</p>
    </div>
  );
}
