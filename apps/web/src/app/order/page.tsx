'use client';

import { useEffect, useState } from 'react';
import { CheckCircle2, ShoppingBag } from 'lucide-react';
import { apiOrigin } from '@/lib/api';
import { Logo } from '@/components/ui';

interface Item { id: string; name: string; isNew: boolean; availability: string; coverPhoto: { url: string; thumbUrl: string } | null; colors: { id: string; name: string | null; hex: string | null }[] }

/**
 * diamoraa.uz/order — «Заказать» for customers (no account, no payment online - the owner's decision): pick an item
 * from the published catalog, a colour and metres, leave a name and a phone. Staff call back from «Заказы клиентов».
 */
export default function OrderPage() {
  const [items, setItems] = useState<Item[] | null>(null);
  const [failed, setFailed] = useState(false);
  const [picked, setPicked] = useState<Item | null>(null);
  const [color, setColor] = useState('');
  const [meters, setMeters] = useState('');
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('+998 ');
  const [comment, setComment] = useState('');
  const [website, setWebsite] = useState(''); // a trap for bots: hidden from people
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);

  useEffect(() => {
    fetch(`${apiOrigin()}/v1/public/catalog`).then((r) => (r.ok ? r.json() : Promise.reject(r))).then((d: { items: Item[] }) => setItems(d.items)).catch(() => setFailed(true));
  }, []);

  const send = async () => {
    setSending(true);
    setError(null);
    try {
      const res = await fetch(`${apiOrigin()}/v1/public/orders`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          name: name.trim(), phone: phone.trim(), productModelId: picked?.id, colorName: color || undefined,
          quantity: meters ? Number(meters.replace(',', '.')) : undefined, comment: comment.trim() || undefined, website: website || undefined,
        }),
      });
      if (res.status === 429) throw new Error('Слишком много заказов подряд. Попробуйте через 10 минут или позвоните нам.');
      if (!res.ok) throw new Error('Проверьте имя и номер телефона.');
      const r = (await res.json()) as { code: string | null };
      setDone(r.code ?? 'ok');
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setSending(false);
    }
  };

  const phoneOk = phone.replace(/\D/g, '').length >= 9;
  if (done) {
    return (
      <main className="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center px-5 text-center">
        <CheckCircle2 size={72} className="text-ok" aria-hidden />
        <h1 className="mt-4 text-2xl font-extrabold">Спасибо, заказ принят!</h1>
        {done !== 'ok' && <p className="mt-2 text-lg">Номер заказа: <b>{done}</b></p>}
        <p className="mt-2 text-muted">Мы позвоним вам по номеру {phone.trim()}, чтобы уточнить детали и срок.</p>
        <a href="/order" className="mt-8 text-primary underline" onClick={() => setDone(null)}>Заказать ещё</a>
      </main>
    );
  }

  return (
    <main className="mx-auto min-h-screen max-w-3xl px-4 pb-16 pt-8 sm:px-6">
      <div className="mb-6 flex items-center gap-3">
        <Logo size={44} />
        <div>
          <h1 className="text-2xl font-extrabold tracking-tight">Заказать изделие</h1>
          <p className="text-sm text-muted">Выберите изделие, цвет и сколько метров — мы перезвоним</p>
        </div>
      </div>

      <h2 className="mb-2 font-semibold">1. Изделие</h2>
      {failed && <p className="rounded-xl bg-danger/10 p-4 text-sm text-danger">Каталог сейчас не открывается. Попробуйте позже или позвоните нам.</p>}
      {!items && !failed && <p className="text-muted">Загружаем каталог…</p>}
      {items && items.length === 0 && <p className="text-muted">Каталог скоро появится. Напишите, что хотите, в комментарии ниже.</p>}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        {items?.map((it) => (
          <button
            key={it.id}
            type="button"
            onClick={() => { setPicked(it); setColor(''); }}
            aria-pressed={picked?.id === it.id}
            className={`overflow-hidden rounded-2xl border-2 bg-card text-left transition ${picked?.id === it.id ? 'border-primary shadow-lg shadow-primary/20' : 'border-border hover:border-primary/40'}`}
          >
            <div className="aspect-square bg-border/40">
              {it.coverPhoto && <img src={it.coverPhoto.thumbUrl} alt="" className="h-full w-full object-cover" loading="lazy" />}
            </div>
            <div className="p-2.5">
              <p className="font-semibold leading-tight">{it.name}</p>
              {it.availability === 'ON_REQUEST' && <p className="text-xs text-muted">под заказ</p>}
              <div className="mt-1.5 flex flex-wrap gap-1">
                {it.colors.slice(0, 8).map((c) => <span key={c.id} title={c.name ?? ''} className="h-3.5 w-3.5 rounded-full border border-border" style={{ background: c.hex ?? undefined }} />)}
              </div>
            </div>
          </button>
        ))}
      </div>

      {picked && picked.colors.length > 0 && (
        <>
          <h2 className="mb-2 mt-6 font-semibold">2. Цвет</h2>
          <div className="flex flex-wrap gap-2">
            {picked.colors.map((c) => (
              <button key={c.id} type="button" onClick={() => setColor(c.name ?? '')} aria-pressed={color === c.name}
                className={`flex items-center gap-2 rounded-full border-2 px-4 py-2 text-sm font-medium ${color === c.name ? 'border-primary bg-primary/10' : 'border-border'}`}>
                <span className="h-4 w-4 rounded-full border border-border" style={{ background: c.hex ?? undefined }} />{c.name}
              </button>
            ))}
          </div>
        </>
      )}

      <h2 className="mb-2 mt-6 font-semibold">{picked ? '3.' : '2.'} Сколько и кому</h2>
      <div className="space-y-3 rounded-2xl border border-border bg-card p-4">
        <label className="block text-sm">Сколько метров (можно примерно)
          <input inputMode="decimal" value={meters} onChange={(e) => setMeters(e.target.value.replace(/[^\d.,]/g, ''))} placeholder="например, 27" className="mt-1 block w-full rounded-xl border border-border bg-background px-3 py-3 text-base" />
        </label>
        <label className="block text-sm">Ваше имя *
          <input value={name} onChange={(e) => setName(e.target.value)} autoComplete="name" className="mt-1 block w-full rounded-xl border border-border bg-background px-3 py-3 text-base" />
        </label>
        <label className="block text-sm">Телефон *
          <input type="tel" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} autoComplete="tel" className="mt-1 block w-full rounded-xl border border-border bg-background px-3 py-3 text-base" />
        </label>
        <label className="block text-sm">Комментарий
          <textarea value={comment} onChange={(e) => setComment(e.target.value)} rows={3} placeholder="Срок, пожелания, адрес доставки…" className="mt-1 block w-full rounded-xl border border-border bg-background px-3 py-3 text-base" />
        </label>
        {/* bots fill every field; people never see this one */}
        <input tabIndex={-1} autoComplete="off" aria-hidden className="absolute -left-[9999px] h-0 w-0 opacity-0" value={website} onChange={(e) => setWebsite(e.target.value)} name="website" />
        {error && <p className="rounded-xl bg-danger/10 p-3 text-sm text-danger" role="alert">{error}</p>}
        <button type="button" onClick={send} disabled={sending || name.trim().length < 2 || !phoneOk}
          className="flex min-h-14 w-full items-center justify-center gap-2 rounded-2xl bg-primary px-5 text-lg font-bold text-white shadow-lg shadow-primary/25 disabled:opacity-50">
          <ShoppingBag size={22} aria-hidden /> {sending ? 'Отправляем…' : 'Отправить заказ'}
        </button>
        <p className="text-center text-xs text-muted">Мы перезвоним и уточним срок, цену и оплату.</p>
      </div>
    </main>
  );
}
