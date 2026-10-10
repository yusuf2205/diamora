'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRef } from 'react';
import { api } from '@/lib/api';
import { Button, Card, ErrorState } from '@/components/ui';

interface Instruction { id: string; name: string; video: { url: string } | null }

/** «Как шить»: one instruction video per model; the worker opens it right from her work card. */
export function InstructionCard({ modelId, canManage }: { modelId: string; canManage: boolean }) {
  const qc = useQueryClient();
  const input = useRef<HTMLInputElement>(null);
  const q = useQuery<Instruction>({ queryKey: ['instruction', modelId], queryFn: () => api.get<Instruction>(`/admin/catalog/${modelId}/instruction`) });
  const done = (r: Instruction) => { qc.setQueryData(['instruction', modelId], r); if (input.current) input.current.value = ''; };
  const upload = useMutation({
    mutationFn: (file: File) => { const form = new FormData(); form.append('file', file); return api.upload<Instruction>(`/admin/catalog/${modelId}/instruction`, form); },
    onSuccess: done,
  });
  const remove = useMutation({ mutationFn: () => api.delete<Instruction>(`/admin/catalog/${modelId}/instruction`), onSuccess: done });
  return (
    <Card className="space-y-3">
      <h3 className="font-medium">Видео «Как шить»</h3>
      <p className="text-sm text-muted">Короткий ролик для мастериц: как шить эту модель. Они откроют его прямо из своей работы.</p>
      {q.error && <ErrorState error={q.error} />}
      {q.data?.video ? (
        <video src={q.data.video.url} controls preload="metadata" className="max-h-72 w-full rounded-lg bg-black" />
      ) : q.data && <p className="text-sm text-muted">Видео пока нет</p>}
      {canManage && (
        <div className="flex flex-wrap items-center gap-2">
          <input ref={input} type="file" accept="video/*" className="text-sm" disabled={upload.isPending}
            onChange={(e) => { const f = e.target.files?.[0]; if (f) upload.mutate(f); }} />
          {upload.isPending && <span className="text-xs text-muted">Загрузка…</span>}
          {q.data?.video && <Button variant="outline" onClick={() => remove.mutate()} disabled={remove.isPending}>Удалить видео</Button>}
        </div>
      )}
      {upload.isError && <ErrorState error={upload.error} />}
    </Card>
  );
}
