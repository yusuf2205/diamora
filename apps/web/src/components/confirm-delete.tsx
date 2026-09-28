'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { Button, ErrorState, Modal } from '@/components/ui';

/** The one «Удалить?» dialog of the panel: what will happen in plain words, a red button, the reason if the server refuses. */
export function ConfirmDelete({ title, children, action, invalidate, onClose, onDone }: {
  title: string; children: ReactNode; action: () => Promise<unknown>; invalidate: string[][]; onClose: () => void; onDone?: () => void;
}) {
  const qc = useQueryClient();
  const remove = useMutation({
    mutationFn: action,
    onSuccess: () => { invalidate.forEach((queryKey) => qc.invalidateQueries({ queryKey })); onClose(); onDone?.(); },
  });
  return (
    <Modal title={title} onClose={onClose}>
      <div className="text-sm">{children}</div>
      {remove.isError && <div className="mt-2"><ErrorState error={remove.error} /></div>}
      <div className="flex justify-end gap-2 pt-4">
        <Button variant="ghost" onClick={onClose}>Отмена</Button>
        <Button variant="danger" disabled={remove.isPending} onClick={() => remove.mutate()}>{remove.isPending ? 'Удаляем…' : 'Удалить'}</Button>
      </div>
    </Modal>
  );
}
