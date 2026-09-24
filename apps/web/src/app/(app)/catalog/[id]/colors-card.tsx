'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { api } from '@/lib/api';
import type { CatalogItem } from '@/lib/types';
import { Button, Card, ErrorState, Field, Input, Select } from '@/components/ui';

interface Color { id: string; name: string; hex: string | null; isActive: boolean }

/** «Цвета» of a model: the colours a worker can be given this model in. A model with no colour cannot be issued —
 * «Выдать работу» needs one. Pick an existing colour or type a new name (created on the spot, then attached). */
export function ColorsCard({ item, canManage }: { item: CatalogItem; canManage: boolean }) {
  const qc = useQueryClient();
  const colors = useQuery<{ items: Color[] }>({ queryKey: ['colors'], queryFn: () => api.get<{ items: Color[] }>('/admin/colors'), enabled: canManage });
  const [colorId, setColorId] = useState('');
  const [newName, setNewName] = useState('');
  const used = new Set(item.variants.map((v) => v.color?.id));
  const free = (colors.data?.items ?? []).filter((c) => c.isActive && !used.has(c.id));

  const add = useMutation({
    mutationFn: async () => {
      let id = colorId;
      if (!id) id = (await api.post<Color>('/admin/colors', { name: newName.trim() }, { idempotencyKey: crypto.randomUUID() })).id;
      return api.post(`/admin/catalog/${item.id}/variants`, { colorId: id }, { idempotencyKey: crypto.randomUUID() });
    },
    onSuccess: () => {
      setColorId('');
      setNewName('');
      qc.invalidateQueries({ queryKey: ['catalog-item', item.id] });
      qc.invalidateQueries({ queryKey: ['admin-catalog'] });
      qc.invalidateQueries({ queryKey: ['colors'] });
    },
  });

  return (
    <Card className="space-y-3">
      <h3 className="font-medium">Цвета</h3>
      {item.variants.length === 0 ? (
        <p className="text-sm text-danger">Пока нет ни одного цвета — эту модель нельзя выдать мастерице.</p>
      ) : (
        <div className="flex flex-wrap gap-2">
          {item.variants.map((v) => (
            <span key={v.id} className={`inline-flex items-center gap-2 rounded-full border border-border px-3 py-1 text-sm ${v.active ? '' : 'opacity-50'}`}>
              <span className="h-3 w-3 rounded-full border border-border" style={{ background: v.color?.hex ?? 'transparent' }} />
              {v.color?.name ?? '—'}{v.label ? ` · ${v.label}` : ''}
            </span>
          ))}
        </div>
      )}
      {canManage && (
        <div className="space-y-2 border-t border-border pt-3">
          {free.length > 0 && (
            <Field label="Добавить готовый цвет" htmlFor="add-color">
              <Select id="add-color" value={colorId} onChange={(e) => { setColorId(e.target.value); setNewName(''); }}>
                <option value="">Выберите цвет</option>
                {free.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
              </Select>
            </Field>
          )}
          <Field label={free.length > 0 ? 'или новый цвет' : 'Новый цвет'} htmlFor="new-color">
            <Input id="new-color" placeholder="Например: Розовое золото" value={newName} onChange={(e) => { setNewName(e.target.value); setColorId(''); }} />
          </Field>
          {add.isError && <ErrorState error={add.error} />}
          <Button onClick={() => add.mutate()} disabled={add.isPending || (!colorId && newName.trim().length < 1)}>+ Добавить цвет</Button>
        </div>
      )}
    </Card>
  );
}
