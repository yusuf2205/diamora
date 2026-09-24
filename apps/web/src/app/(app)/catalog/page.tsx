'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { api } from '@/lib/api';
import { hasPerm } from '@/lib/types';
import { statusLabel } from '@/lib/format';
import { useAuth } from '@/lib/auth';
import type { CatalogItem, Page } from '@/lib/types';
import { Badge, Button, EmptyState, ErrorState, Input, Modal } from '@/components/ui';

const STATUS_TONE: Record<CatalogItem['status'], 'default' | 'ok' | 'warn'> = { DRAFT: 'warn', PUBLISHED: 'ok', HIDDEN: 'default' };

/** "Наши работы" management (§16). WORKER never sees this route; the public catalog has no price field at all (D-029). */
export default function CatalogPage() {
  const { me } = useAuth();
  const router = useRouter();
  const qc = useQueryClient();
  const [creating, setCreating] = useState(false);
  const canManage = hasPerm(me, 'CATALOG_MANAGE');

  const { data, error, isLoading } = useQuery<Page<CatalogItem>>({ queryKey: ['admin-catalog'], queryFn: () => api.get<Page<CatalogItem>>('/admin/catalog', { limit: 100 }) });

  const publish = useMutation({
    mutationFn: (id: string) => api.post(`/admin/catalog/${id}/publish`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-catalog'] }),
  });
  const hide = useMutation({
    mutationFn: (id: string) => api.post(`/admin/catalog/${id}/hide`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-catalog'] }),
  });

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold">Каталог работ</h1>
          <p className="text-sm text-muted">«Наши работы» в приложении мастериц — без цены, только фото и описание.</p>
        </div>
        {canManage && <Button onClick={() => setCreating(true)}>Добавить работу</Button>}
      </div>
      {error && <ErrorState error={error} />}
      {isLoading && <p className="text-muted">Загрузка…</p>}
      {data && data.items.length === 0 && <EmptyState title="Пока ничего нет" hint="Добавьте первую работу" />}
      {data && data.items.length > 0 && (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
          {data.items.map((item) => (
            <div key={item.id} className="overflow-hidden rounded-lg border border-border bg-card">
              <button onClick={() => router.push(`/catalog/${item.id}`)} className="block w-full text-left">
                <div className="flex h-40 items-center justify-center bg-border/30">
                  {item.media[0]?.file ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={item.media[0].file.thumbUrl ?? item.media[0].file.url} alt={item.name} className="h-full w-full object-cover" />
                  ) : (
                    <span className="text-muted">Нет фото</span>
                  )}
                </div>
                <div className="space-y-2 p-3 pb-0">
                  <p className="truncate font-medium">{item.name}</p>
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <Badge tone={STATUS_TONE[item.status]}>{statusLabel(item.status)}</Badge>
                    {item.isNew && <Badge tone="warn">Новинка</Badge>}
                  </div>
                </div>
              </button>
              {canManage && (
                <div className="flex gap-2 p-3 pt-2">
                  {item.status === 'PUBLISHED' ? (
                    <Button variant="outline" className="flex-1" onClick={() => hide.mutate(item.id)} disabled={hide.isPending}>Скрыть</Button>
                  ) : (
                    <Button variant="outline" className="flex-1" onClick={() => publish.mutate(item.id)} disabled={publish.isPending}>Опубликовать</Button>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
      {creating && <CreateDialog onClose={() => setCreating(false)} />}
    </div>
  );
}

function CreateDialog({ onClose }: { onClose: () => void }) {
  const qc = useQueryClient();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const create = useMutation({
    mutationFn: () => api.post<CatalogItem>('/admin/catalog', { name: name.trim(), description: description.trim() || undefined }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin-catalog'] });
      onClose();
    },
  });

  return (
    <Modal title="Новая работа" onClose={onClose}>
      <div className="space-y-3">
        <Input placeholder="Название" value={name} onChange={(e) => setName(e.target.value)} autoFocus />
        <Input placeholder="Описание (необязательно)" value={description} onChange={(e) => setDescription(e.target.value)} />
        {create.isError && <ErrorState error={create.error} />}
        <p className="text-xs text-muted">Фото добавляются после создания (в мобильном приложении ADMIN — модуль загрузки фото и видео).</p>
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button onClick={() => create.mutate()} disabled={!name.trim() || create.isPending}>Создать</Button>
        </div>
      </div>
    </Modal>
  );
}
