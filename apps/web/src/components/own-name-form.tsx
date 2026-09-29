'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { Button, Card, ErrorState, Field, Input } from '@/components/ui';

/** «Имя и фамилия»: split for editing on the first space, saved back as one fullName. */
export function splitName(fullName: string): [string, string] {
  const s = fullName.trim();
  const i = s.indexOf(' ');
  return i < 0 ? [s, ''] : [s.slice(0, i), s.slice(i + 1).trim()];
}

/** Anyone changes their OWN first name and surname (PATCH /auth/me). */
export function OwnNameForm({ fullName, invalidate }: { fullName: string | undefined; invalidate: string[][] }) {
  const qc = useQueryClient();
  const [first, setFirst] = useState('');
  const [last, setLast] = useState('');
  const [saved, setSaved] = useState(false);
  useEffect(() => {
    if (fullName === undefined) return;
    const [f, l] = splitName(fullName);
    setFirst(f);
    setLast(l);
  }, [fullName]);
  const next = `${first.trim()} ${last.trim()}`.trim();
  const save = useMutation({
    mutationFn: () => api.patch('/auth/me', { fullName: next }),
    onSuccess: async () => {
      setSaved(true);
      await Promise.all(invalidate.map((queryKey) => qc.invalidateQueries({ queryKey })));
    },
  });
  const changed = fullName !== undefined && next !== fullName.trim();
  return (
    <Card className="space-y-3">
      <h2 className="font-medium">Имя и фамилия</h2>
      <Field label="Имя" htmlFor="own-first"><Input id="own-first" autoComplete="given-name" value={first} onChange={(e) => { setSaved(false); setFirst(e.target.value); }} /></Field>
      <Field label="Фамилия" htmlFor="own-last"><Input id="own-last" autoComplete="family-name" value={last} onChange={(e) => { setSaved(false); setLast(e.target.value); }} /></Field>
      {save.isError && <ErrorState error={save.error} />}
      {saved && !changed && <p className="text-sm text-ok" role="status">✓ Сохранено</p>}
      <Button onClick={() => save.mutate()} disabled={save.isPending || !changed || first.trim().length < 2}>Сохранить</Button>
    </Card>
  );
}
