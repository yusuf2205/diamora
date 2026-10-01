'use client';

import { useEffect, useState } from 'react';
import { CheckCircle2, Send, ShoppingBag, X } from 'lucide-react';
import { apiOrigin } from '@/lib/api';
import { Logo } from '@/components/ui';

interface Item { id: string; name: string; isNew: boolean; availability: string; coverPhoto: { url: string; thumbUrl: string } | null; colors: { id: string; name: string | null; hex: string | null }[] }
interface Detail { id: string; name: string; description: string | null; media: { id: string; kind: string; file: { url: string; thumbUrl?: string } | null }[] }

/**
 * shop.diamoraa.uz — the customers' own door (owner, 2026-10-01): the published catalog, an item with its photos and
 * colours, «Заказать» with a name and a phone (no account, no online payment). Staff call back from «Заказы клиентов»;
 * with the shop bot the customer also hears about every step in Telegram.
 */
export default function ShopPage() {
  const [items, setItems] = useState<Item[] | null>(null);
  const [bot, setBot] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);
  const [open, setOpen] = useState<Item | null>(null);
  const [done, setDone] = useState<{ code: string | null; follow: string | null; phone: string } | null>(null);

  useEffect(() => {
    fetch(`${apiOrigin()}/v1/public/catalog`).then((r) => (r.ok ? r.json() : Promise.reject(r)))
      .then((d: { items: Item[]; bot: string | null }) => { setItems(d.items); setBot(d.bot); }).catch(() => setFailed(true));
  }, []);

  if (done) {
    return (
      <main className="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center px-5 text-center">
        <CheckCircle2 size={72} className="text-ok" aria-hidden />
        <h1 className="mt-4 text-2xl font-extrabold">Спасибо, заказ принят!</h1>
        {done.code && <p className="mt-2 text-lg">Номер заказа: <b>{done.code}</b></p>}
        <p className="mt-2 text-muted">Мы позвоним по номеру {done.phone}, чтобы уточнить детали, срок и цену.</p>
        {done.follow && (
          <a href={done.follow} target="_blank" rel="noopener noreferrer"
            className="mt-6 flex min-h-14 w-full items-center justify-center gap-2 rounded-2xl bg-[#229ED9] px-5 text-lg font-bold text-white">
            <Send size={20} aria-hidden /> Следить за заказом в Telegram
          </a>
        )}
        <button type="button" className="mt-6 text-primary underline" onClick={() => setDone(null)}>Вернуться в каталог</button>
      </main>
    );
  }

  return (
    <main className="mx-auto min-h-screen max-w-5xl px-4 pb-16 pt-6 sm:px-6">
      <header className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Logo size={44} />
          <div>
            <h1 className="text-2xl font-extrabold tracking-tight">Diamoraa</h1>
            <p className="text-sm text-muted">Выберите изделие — мы перезвоним и всё уточним</p>
          </div>
        </div>
        {bot && (
          <a href={`https://t.me/${bot}`} target="_blank" rel="noopener noreferrer"
            className="inline-flex min-h-11 items-center gap-2 rounded-xl border border-border bg-card px-4 font-semibold hover:bg-border/40">
            <Send size={18} className="text-[#229ED9]" aria-hidden /> Заказать в Telegram
          </a>
        )}
      </header>

      {failed && <p className="rounded-xl bg-danger/10 p-4 text-sm text-danger">Каталог сейчас не открывается. Попробуйте позже.</p>}
      {!items && !failed && <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">{[0, 1, 2, 3].map((i) => <div key={i} className="aspect-[3/4] animate-pulse rounded-2xl bg-border/50" />)}</div>}
      {items?.length === 0 && <p className="text-muted">Каталог скоро появится.</p>}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        {items?.map((it) => (
          <button key={it.id} type="button" onClick={() => setOpen(it)}
            className="overflow-hidden rounded-2xl border border-border bg-card text-left transition hover:border-primary/50 hover:shadow-lg">
            <div className="relative aspect-square bg-border/40">
              {it.coverPhoto && <img src={it.coverPhoto.thumbUrl} alt="" className="h-full w-full object-cover" loading="lazy" />}
              {it.isNew && <span className="absolute left-2 top-2 rounded-full bg-primary px-2 py-0.5 text-xs font-bold text-white">Новинка</span>}
            </div>
            <div className="p-3">
              <p className="font-semibold leading-tight">{it.name}</p>
              {it.availability === 'ON_REQUEST' && <p className="text-xs text-muted">под заказ</p>}
              <div className="mt-2 flex flex-wrap gap-1">
                {it.colors.slice(0, 10).map((c) => <span key={c.id} title={c.name ?? ''} className="h-4 w-4 rounded-full border border-border" style={{ background: c.hex ?? undefined }} />)}
              </div>
            </div>
          </button>
        ))}
      </div>

      {open && <OrderSheet item={open} onClose={() => setOpen(null)} onDone={(d) => { setOpen(null); setDone(d); }} />}
    </main>
  );
}

function OrderSheet({ item, onClose, onDone }: { item: Item; onClose: () => void; onDone: (d: { code: string | null; follow: string | null; phone: string }) => void }) {
  const [detail, setDetail] = useState<Detail | null>(null);
  const [photo, setPhoto] = useState(0);
  const [color, setColor] = useState('');
  const [meters, setMeters] = useState('');
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('+998 ');
  const [comment, setComment] = useState('');
  const [website, setWebsite] = useState(''); // a trap for bots: hidden from people
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch(`${apiOrigin()}/v1/public/catalog/${item.id}`).then((r) => (r.ok ? r.json() : null)).then(setDetail).catch(() => undefined);
    const esc = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', esc);
    document.body.style.overflow = 'hidden';
    return () => { document.removeEventListener('keydown', esc); document.body.style.overflow = ''; };
  }, [item.id, onClose]);

  const photos = (detail?.media ?? []).filter((m) => m.kind === 'PHOTO' && m.file).map((m) => m.file!.url);
  const shown = photos[photo] ?? item.coverPhoto?.url;
  const phoneOk = phone.replace(/\D/g, '').length >= 9;

  const send = async () => {
    setSending(true);
    setError(null);
    try {
      const res = await fetch(`${apiOrigin()}/v1/public/orders`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          name: name.trim(), phone: phone.trim(), productModelId: item.id, colorName: color || undefined,
          quantity: meters ? Number(meters.replace(',', '.')) : undefined, comment: comment.trim() || undefined, website: website || undefined,
        }),
      });
      if (res.status === 429) throw new Error('Слишком много заказов подряд. Попробуйте через 10 минут.');
      if (!res.ok) throw new Error('Проверьте имя и номер телефона.');
      const r = (await res.json()) as { code: string | null; follow: string | null };
      onDone({ code: r.code, follow: r.follow, phone: phone.trim() });
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 sm:items-center sm:p-4" onClick={onClose}>
      <div role="dialog" aria-modal aria-label={item.name} onClick={(e) => e.stopPropagation()}
        className="max-h-[92vh] w-full overflow-y-auto rounded-t-3xl bg-background sm:max-w-3xl sm:rounded-3xl">
        <div className="sticky top-0 z-10 flex items-center justify-between border-b border-border bg-background/95 px-4 py-3 backdrop-blur">
          <h2 className="text-lg font-bold">{item.name}</h2>
          <button type="button" onClick={onClose} aria-label="Закрыть" className="grid h-10 w-10 place-items-center rounded-full hover:bg-border/50"><X size={22} /></button>
        </div>
        <div className="grid gap-5 p-4 sm:grid-cols-2">
          <div>
            <div className="aspect-square overflow-hidden rounded-2xl bg-border/40">
              {shown && <img src={shown} alt={item.name} className="h-full w-full object-cover" />}
            </div>
            {photos.length > 1 && (
              <div className="mt-2 flex gap-2 overflow-x-auto pb-1">
                {photos.map((u, i) => (
                  <button key={u} type="button" onClick={() => setPhoto(i)} aria-label={`Фото ${i + 1}`}
                    className={`h-16 w-16 shrink-0 overflow-hidden rounded-xl border-2 ${i === photo ? 'border-primary' : 'border-transparent'}`}>
                    <img src={u} alt="" className="h-full w-full object-cover" loading="lazy" />
                  </button>
                ))}
              </div>
            )}
            {detail?.description && <p className="mt-3 whitespace-pre-line text-sm text-muted">{detail.description}</p>}
          </div>

          <div className="space-y-3">
            {item.colors.length > 0 && (
              <div>
                <p className="mb-2 text-sm font-semibold">Цвет</p>
                <div className="flex flex-wrap gap-2">
                  {item.colors.map((c) => (
                    <button key={c.id} type="button" onClick={() => setColor(c.name ?? '')} aria-pressed={color === c.name}
                      className={`flex items-center gap-2 rounded-full border-2 px-3 py-1.5 text-sm font-medium ${color === c.name ? 'border-primary bg-primary/10' : 'border-border'}`}>
                      <span className="h-4 w-4 rounded-full border border-border" style={{ background: c.hex ?? undefined }} />{c.name}
                    </button>
                  ))}
                </div>
              </div>
            )}
            <label className="block text-sm">Сколько метров (можно примерно)
              <input inputMode="decimal" value={meters} onChange={(e) => setMeters(e.target.value.replace(/[^\d.,]/g, ''))} placeholder="например, 27" className="mt-1 block w-full rounded-xl border border-border bg-card px-3 py-3 text-base" />
            </label>
            <label className="block text-sm">Ваше имя *
              <input value={name} onChange={(e) => setName(e.target.value)} autoComplete="name" className="mt-1 block w-full rounded-xl border border-border bg-card px-3 py-3 text-base" />
            </label>
            <label className="block text-sm">Телефон *
              <input type="tel" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} autoComplete="tel" className="mt-1 block w-full rounded-xl border border-border bg-card px-3 py-3 text-base" />
            </label>
            <label className="block text-sm">Комментарий
              <textarea value={comment} onChange={(e) => setComment(e.target.value)} rows={2} placeholder="Срок, пожелания, адрес доставки…" className="mt-1 block w-full rounded-xl border border-border bg-card px-3 py-3 text-base" />
            </label>
            {/* bots fill every field; people never see this one */}
            <input tabIndex={-1} autoComplete="off" aria-hidden className="absolute -left-[9999px] h-0 w-0 opacity-0" value={website} onChange={(e) => setWebsite(e.target.value)} name="website" />
            {error && <p className="rounded-xl bg-danger/10 p-3 text-sm text-danger" role="alert">{error}</p>}
            <button type="button" onClick={send} disabled={sending || name.trim().length < 2 || !phoneOk}
              className="flex min-h-14 w-full items-center justify-center gap-2 rounded-2xl bg-primary px-5 text-lg font-bold text-white shadow-lg shadow-primary/25 disabled:opacity-50">
              <ShoppingBag size={22} aria-hidden /> {sending ? 'Отправляем…' : 'Заказать'}
            </button>
            <p className="text-center text-xs text-muted">Оплата не нужна сейчас — мы перезвоним и уточним срок и цену.</p>
          </div>
        </div>
      </div>
    </div>
  );
}
