'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { api, ApiError } from '@/lib/api';
import { Button, Card, ErrorState, Input, ListSkeleton, Modal } from '@/components/ui';

/** A card of the list (GET /catalog): no colours or description — those come with the item itself. */
interface Item { id: string; name: string; availability: string; isNew: boolean; coverPhoto: { url: string; thumbUrl?: string } | null }
/** One item (GET /catalog/:id): only active colours of a published item are ever returned. */
interface ItemDetail {
  id: string; name: string; description: string | null; availability: string;
  media: { id: string; kind: string; file: { url: string } | null }[];
  variants: { id: string; label: string | null; color: { id: string; name: string; hex: string | null } | null }[];
}

/** «Наши работы» + «Заказать эту работу» (colour, 9/18/27 м, a wish) — the same as in the app. */
export default function WorkerCatalog() {
  const { data, error, isLoading } = useQuery<{ items: Item[] }>({ queryKey: ['w-catalog'], queryFn: () => api.get('/catalog') });
  const [ordering, setOrdering] = useState<Item | null>(null);
  return (
    <div className="space-y-3">
      <h1 className="text-2xl font-extrabold">Наши работы</h1>
      {error && <ErrorState error={error} />}
      {isLoading && <ListSkeleton />}
      {data?.items.length === 0 && <Card><p className="text-sm text-muted">Скоро здесь появятся работы.</p></Card>}
      <div className="grid grid-cols-2 gap-3">
        {data?.items.map((i) => (
          <button key={i.id} onClick={() => setOrdering(i)} className="overflow-hidden rounded-2xl border border-border bg-card text-left">
            {i.coverPhoto ? <img src={i.coverPhoto.thumbUrl ?? i.coverPhoto.url} alt="" className="aspect-square w-full object-cover" /> : <div className="aspect-square w-full bg-primary/10" />}
            <div className="p-2">
              <p className="line-clamp-2 text-sm font-bold">{i.name}</p>
              {i.availability === 'UNAVAILABLE' && <p className="text-xs text-muted">Сейчас нет</p>}
            </div>
          </button>
        ))}
      </div>
      {ordering && <OrderDialog item={ordering} onClose={() => setOrdering(null)} />}
    </div>
  );
}

function OrderDialog({ item: card, onClose }: { item: Item; onClose: () => void }) {
  const detail = useQuery<ItemDetail>({ queryKey: ['w-catalog', card.id], queryFn: () => api.get<ItemDetail>(`/catalog/${card.id}`) });
  return (
    <Modal title={card.name} onClose={onClose}>
      {detail.error && <ErrorState error={detail.error} />}
      {detail.isLoading && <ListSkeleton rows={2} />}
      {detail.data && <OrderForm item={detail.data} cover={card.coverPhoto?.url ?? null} />}
    </Modal>
  );
}

function OrderForm({ item, cover }: { item: ItemDetail; cover: string | null }) {
  const qc = useQueryClient();
  const router = useRouter();
  const variants = item.variants.filter((v) => v.color);
  const [variantId, setVariantId] = useState(variants.length === 1 ? variants[0].id : '');
  const [kits, setKits] = useState(1);
  const [note, setNote] = useState('');
  const [msg, setMsg] = useState<string | null>(null);
  const order = useMutation({
    mutationFn: () => api.post('/work/requests', { productVariantId: variantId, kitCount: kits, note: note.trim() || undefined }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['w-reqs'] }); router.push('/w'); },
    onError: (e) => setMsg(e instanceof ApiError && e.code === 'CONFLICT' ? 'У вас уже есть заявка — дождитесь ответа или отмените её на главной.' : null),
  });
  const orderable = item.availability !== 'UNAVAILABLE' && variants.length > 0;
  return (
      <div className="space-y-3">
        {cover && <img src={cover} alt="" className="max-h-64 w-full rounded-xl object-cover" />}
        {item.description && <p className="text-sm">{item.description}</p>}
        {orderable ? (
          <>
            <p className="text-sm font-semibold">Цвет</p>
            <div className="flex flex-wrap gap-2">
              {variants.map((v) => (
                <button key={v.id} onClick={() => setVariantId(v.id)} className={`flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm ${variantId === v.id ? 'border-primary bg-primary/10 font-bold' : 'border-border'}`}>
                  <span className="h-3 w-3 rounded-full" style={{ background: v.color!.hex ?? '#ccc' }} />{v.color!.name}{v.label ? ` · ${v.label}` : ''}
                </button>
              ))}
            </div>
            <p className="text-sm font-semibold">Сколько метров</p>
            <div className="grid grid-cols-3 gap-2">
              {[1, 2, 3].map((k) => (
                <button key={k} onClick={() => setKits(k)} className={`rounded-xl border py-2 font-bold ${kits === k ? 'border-primary bg-primary/10' : 'border-border'}`}>{k * 9} м</button>
              ))}
            </div>
            <Input placeholder="Пожелание (необязательно)" aria-label="Пожелание" value={note} onChange={(e) => setNote(e.target.value)} />
            {msg ? <p className="rounded-lg bg-primary/10 p-2 text-sm">{msg}</p> : order.isError && <ErrorState error={order.error} />}
            <Button className="w-full" disabled={!variantId || order.isPending} onClick={() => order.mutate()}>Заказать эту работу</Button>
          </>
        ) : <p className="text-sm text-muted">Сейчас эту работу заказать нельзя.</p>}
      </div>
  );
}
