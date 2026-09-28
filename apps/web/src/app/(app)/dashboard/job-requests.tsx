'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { api } from '@/lib/api';
import type { JobRequest } from '@/lib/types';
import { Button, Card, ErrorState, Input, Modal } from '@/components/ui';
import { CreateAssignmentDialog } from '../assignments/page';

/** «Заявки на работу»: what workers ordered in the app. «Подготовить работу» opens the usual dialog already filled in. */
export function JobRequestsCard({ canCreate }: { canCreate: boolean }) {
  const qc = useQueryClient();
  const { data } = useQuery<{ items: JobRequest[] }>({ queryKey: ['job-requests'], queryFn: () => api.get<{ items: JobRequest[] }>('/admin/job-requests') });
  const [preparing, setPreparing] = useState<JobRequest | null>(null);
  const [rejecting, setRejecting] = useState<JobRequest | null>(null);
  const [reason, setReason] = useState('');
  const reject = useMutation({
    mutationFn: (r: JobRequest) => api.post(`/admin/job-requests/${r.id}/reject`, { note: reason.trim() || undefined }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { setRejecting(null); setReason(''); qc.invalidateQueries({ queryKey: ['job-requests'] }); },
  });
  if (!data?.items?.length) return null;
  return (
    <Card>
      <h2 className="mb-2 font-semibold">Заявки на работу · {data.items.length}</h2>
      <ul className="divide-y divide-border">
        {data.items.map((r) => (
          <li key={r.id} className="flex flex-col gap-2 py-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="min-w-0">
              <p className="font-medium">{r.worker.fullName}</p>
              <p className="text-sm">
                <span className="mr-1 inline-block h-3 w-3 rounded-full align-middle" style={{ background: r.color?.hex ?? '#ccc' }} />
                {[r.product?.name, r.color?.name].filter(Boolean).join(' · ')} · {r.meters} м
              </p>
              {r.note && <p className="text-sm text-muted">«{r.note}»</p>}
            </div>
            {canCreate && (
              <div className="flex gap-2">
                <Button onClick={() => setPreparing(r)}>Подготовить работу</Button>
                <Button variant="ghost" onClick={() => setRejecting(r)}>Отклонить</Button>
              </div>
            )}
          </li>
        ))}
      </ul>
      {preparing && <CreateAssignmentDialog request={preparing} onClose={() => setPreparing(null)} />}
      {rejecting && (
        <Modal title="Отклонить заявку" onClose={() => setRejecting(null)}>
          <p className="mb-2 text-sm">{rejecting.worker.fullName}: {rejecting.product?.name} · {rejecting.meters} м</p>
          <Input placeholder="Причина (мастерица её увидит)" aria-label="Причина" value={reason} onChange={(e) => setReason(e.target.value)} />
          {reject.isError && <div className="mt-2"><ErrorState error={reject.error} /></div>}
          <div className="flex justify-end gap-2 pt-4">
            <Button variant="ghost" onClick={() => setRejecting(null)}>Отмена</Button>
            <Button variant="danger" disabled={reject.isPending} onClick={() => reject.mutate(rejecting)}>Отклонить</Button>
          </div>
        </Modal>
      )}
    </Card>
  );
}
