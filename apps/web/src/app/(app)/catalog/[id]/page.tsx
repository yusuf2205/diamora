'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useParams, useRouter } from 'next/navigation';
import { useRef, useState } from 'react';
import { api } from '@/lib/api';
import { hasPerm } from '@/lib/types';
import { statusLabel } from '@/lib/format';
import { useAuth } from '@/lib/auth';
import type { CatalogItem, CatalogMedia } from '@/lib/types';
import { Badge, Button, Card, ErrorState, Input, Select } from '@/components/ui';
import { ColorsCard } from './colors-card';

/** Catalog item detail + media (M2 §22, closes the "web upload" gap): create/edit/photo/video/publish/hide/new —
 * everything ADMIN already has in the mobile app, now also on the web. Files go to MinIO on the NAS through the SAME
 * `/admin/catalog/:id/media` endpoint the Flutter app uses; there is still no price field anywhere (D-029). */
export default function CatalogDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { me } = useAuth();
  const qc = useQueryClient();
  const canManage = hasPerm(me, 'CATALOG_MANAGE');
  const fileInput = useRef<HTMLInputElement>(null);
  const [uploadKind, setUploadKind] = useState<'PHOTO' | 'VIDEO'>('PHOTO');

  const { data: item, error, isLoading } = useQuery<CatalogItem>({ queryKey: ['catalog-item', id], queryFn: () => api.get<CatalogItem>(`/admin/catalog/${id}`) });

  const invalidate = () => qc.invalidateQueries({ queryKey: ['catalog-item', id] });
  const patch = useMutation({ mutationFn: (body: Partial<Pick<CatalogItem, 'name' | 'description' | 'availability' | 'isNew'>>) => api.patch(`/admin/catalog/${id}`, body), onSuccess: invalidate });
  const publish = useMutation({ mutationFn: () => api.post(`/admin/catalog/${id}/publish`), onSuccess: invalidate });
  const hide = useMutation({ mutationFn: () => api.post(`/admin/catalog/${id}/hide`), onSuccess: invalidate });
  const upload = useMutation({
    mutationFn: (file: File) => {
      const form = new FormData();
      form.append('kind', uploadKind);
      form.append('file', file);
      return api.upload(`/admin/catalog/${id}/media`, form);
    },
    onSuccess: () => {
      invalidate();
      if (fileInput.current) fileInput.current.value = '';
    },
  });
  const setMain = useMutation({ mutationFn: (mediaId: string) => api.post(`/admin/catalog/media/${mediaId}/main`), onSuccess: invalidate });
  const removeMedia = useMutation({ mutationFn: (mediaId: string) => api.delete(`/admin/catalog/media/${mediaId}`), onSuccess: invalidate });

  if (isLoading) return <p className="text-muted">Загрузка…</p>;
  if (error || !item) return <ErrorState error={error ?? new Error('Не найдено')} />;

  return (
    <div className="max-w-2xl space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <button onClick={() => router.push('/catalog')} className="text-sm text-muted hover:text-foreground">← Каталог</button>
        <div className="flex items-center gap-2">
          <Badge tone={item.status === 'PUBLISHED' ? 'ok' : item.status === 'DRAFT' ? 'warn' : 'default'}>{statusLabel(item.status)}</Badge>
          {item.isNew && <Badge tone="warn">Новинка</Badge>}
        </div>
      </div>

      <Card className="space-y-3">
        <Input defaultValue={item.name} disabled={!canManage} onBlur={(e) => e.target.value !== item.name && patch.mutate({ name: e.target.value })} placeholder="Название" />
        <textarea
          defaultValue={item.description ?? ''}
          disabled={!canManage}
          onBlur={(e) => e.target.value !== (item.description ?? '') && patch.mutate({ description: e.target.value })}
          placeholder="Описание"
          rows={3}
          className="w-full rounded-lg border border-border bg-background px-3 py-2 text-sm outline-none focus:border-primary"
        />
        <div className="flex items-center gap-4">
          <Select disabled={!canManage} value={item.availability} onChange={(e) => patch.mutate({ availability: e.target.value as CatalogItem['availability'] })} className="w-48">
            <option value="AVAILABLE">В наличии</option>
            <option value="ON_REQUEST">Под заказ</option>
            <option value="UNAVAILABLE">Недоступно</option>
          </Select>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={item.isNew} disabled={!canManage} onChange={(e) => patch.mutate({ isNew: e.target.checked })} />
            Новинка
          </label>
        </div>
        {canManage && (
          <div className="flex gap-2 pt-1">
            {item.status === 'PUBLISHED' ? (
              <Button variant="outline" onClick={() => hide.mutate()} disabled={hide.isPending}>Скрыть</Button>
            ) : (
              <Button onClick={() => publish.mutate()} disabled={publish.isPending || item.media.length === 0}>Опубликовать</Button>
            )}
          </div>
        )}
        {item.status !== 'PUBLISHED' && item.media.length === 0 && <p className="text-xs text-muted">Добавьте хотя бы одно фото, чтобы опубликовать.</p>}
      </Card>

      <ColorsCard item={item} canManage={canManage} />

      <Card className="space-y-4">
        <h3 className="font-medium">Фото и видео</h3>
        {item.media.length === 0 && <p className="text-sm text-muted">Пока ничего нет</p>}
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
          {item.media.map((m: CatalogMedia) => (
            <div key={m.id} className="space-y-1">
              <div className="relative flex h-28 items-center justify-center overflow-hidden rounded-lg border border-border bg-border/20">
                {m.kind === 'PHOTO' && m.file ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={m.file.thumbUrl ?? m.file.url} alt="" className="h-full w-full object-cover" />
                ) : (
                  <span className="text-xs text-muted">Видео</span>
                )}
                {m.isMain && <span className="absolute left-1 top-1"><Badge tone="ok">Главное</Badge></span>}
              </div>
              {canManage && (
                <div className="flex gap-1">
                  {m.kind === 'PHOTO' && !m.isMain && <button onClick={() => setMain.mutate(m.id)} className="flex-1 rounded border border-border py-1 text-xs hover:bg-border/40">Главное</button>}
                  <button onClick={() => removeMedia.mutate(m.id)} className="flex-1 rounded border border-border py-1 text-xs text-danger hover:bg-danger/10">Удалить</button>
                </div>
              )}
            </div>
          ))}
        </div>
        {canManage && (
          <div className="flex items-center gap-2 border-t border-border pt-3">
            <Select value={uploadKind} onChange={(e) => setUploadKind(e.target.value as 'PHOTO' | 'VIDEO')} className="w-32">
              <option value="PHOTO">Фото</option>
              <option value="VIDEO">Видео</option>
            </Select>
            <input
              ref={fileInput}
              type="file"
              accept={uploadKind === 'PHOTO' ? 'image/*' : 'video/*'}
              onChange={(e) => { const f = e.target.files?.[0]; if (f) upload.mutate(f); }}
              disabled={upload.isPending}
              className="text-sm"
            />
            {upload.isPending && <span className="text-xs text-muted">Загрузка…</span>}
          </div>
        )}
        {upload.isError && <ErrorState error={upload.error} />}
      </Card>
    </div>
  );
}
