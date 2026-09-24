'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { formatDate, formatUzs } from '@/lib/format';
import { hasPerm } from '@/lib/types';
import { useAuth } from '@/lib/auth';
import type { CompanyContact, Page, PayRate, PayRateChange } from '@/lib/types';
import { Button, Card, ErrorState, Field, Input, PageHeader } from '@/components/ui';

/** Global 9 m price (D-027) and company contact (D-029, §13). Both are settings, both are server-confirmed writes. */
export default function SettingsPage() {
  const { me } = useAuth();
  return (
    <div className="max-w-2xl space-y-6 sm:space-y-8">
      <PageHeader title="Настройки" subtitle="Настройки компании. Личные данные — в меню снизу слева." />
      <PayRateSection canManage={hasPerm(me, 'PAY_RATE_MANAGE')} />
      {hasPerm(me, 'SETTINGS_MANAGE') && <CompanyContactSection />}
    </div>
  );
}

function PayRateSection({ canManage }: { canManage: boolean }) {
  const qc = useQueryClient();
  const [value, setValue] = useState('');
  const rate = useQuery<PayRate>({ queryKey: ['pay-rate'], queryFn: () => api.get<PayRate>('/settings/pay-rate') });
  const history = useQuery<Page<PayRateChange>>({ queryKey: ['pay-rate-history'], queryFn: () => api.get<Page<PayRateChange>>('/settings/pay-rate/history'), enabled: canManage });
  const change = useMutation({
    mutationFn: () => api.put('/settings/pay-rate', { ratePerKit: value.trim() }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['pay-rate'] });
      qc.invalidateQueries({ queryKey: ['pay-rate-history'] });
      setValue('');
    },
  });

  return (
    <section className="space-y-3">
      <h2 className="text-lg font-medium">Ставка за 9 м</h2>
      {rate.error && <ErrorState error={rate.error} />}
      {rate.data && (
        <Card>
          <p className="text-sm text-muted">Оплата за один комплект {rate.data.kitMeters} м. Ставка одна для всех, меняется сразу у всех мастериц. Уже принятая работа не пересчитывается.</p>
          <p className="mt-2 text-3xl font-semibold">{formatUzs(rate.data.ratePerKit)}</p>
          {canManage && (
            <div className="mt-4 flex flex-col gap-2 sm:flex-row sm:items-end">
              <div className="flex-1">
                <label className="text-sm text-muted" htmlFor="rate">Новая ставка, сум</label>
                <Input id="rate" inputMode="numeric" value={value} onChange={(e) => setValue(e.target.value.replace(/\D/g, ''))} />
              </div>
              <Button onClick={() => change.mutate()} disabled={!value || change.isPending}>Изменить</Button>
            </div>
          )}
          {change.isError && <div className="mt-2"><ErrorState error={change.error} /></div>}
        </Card>
      )}
      {canManage && history.data && history.data.items.length > 0 && (
        <div className="space-y-1 text-sm">
          <p className="font-medium text-muted">История</p>
          {history.data.items.map((h) => (
            <div key={h.id} className="flex flex-col gap-0.5 border-b border-border py-2 sm:flex-row sm:justify-between">
              <span className="font-medium">{h.previousRatePerKit ? `${formatUzs(h.previousRatePerKit)} → ${formatUzs(h.ratePerKit)}` : `${formatUzs(h.ratePerKit)} · начальная`}</span>
              <span className="text-xs text-muted sm:text-sm">{h.changedBy ?? 'Система'} · {formatDate(h.createdAt)}</span>
            </div>
          ))}
        </div>
      )}
    </section>
  );
}

function CompanyContactSection() {
  const qc = useQueryClient();
  const contact = useQuery<CompanyContact>({ queryKey: ['company-contact'], queryFn: () => api.get<CompanyContact>('/settings/company-contact') });
  const [phone, setPhone] = useState('');
  const [telegram, setTelegram] = useState('');
  useEffect(() => {
    if (contact.data) {
      setPhone(contact.data.phone ?? '');
      setTelegram(contact.data.telegramUsername ?? '');
    }
  }, [contact.data]);
  const save = useMutation({
    mutationFn: () => api.put('/settings/company-contact', { phone: phone.trim() || null, telegramUsername: telegram.trim() || null }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['company-contact'] }),
  });

  return (
    <section className="space-y-3">
      <h2 className="text-lg font-medium">Телефон и Telegram компании</h2>
      <p className="text-sm text-muted">Эти данные видят мастерицы в каталоге на кнопках «Позвонить» и «Написать в Telegram».</p>
      <Card className="space-y-3">
        <Field label="Телефон компании" htmlFor="cc-phone"><Input id="cc-phone" type="tel" inputMode="tel" placeholder="+998 90 123 45 67" value={phone} onChange={(e) => setPhone(e.target.value)} /></Field>
        <Field label="Telegram (без @)" htmlFor="cc-tg"><Input id="cc-tg" placeholder="diamoraa" value={telegram} onChange={(e) => setTelegram(e.target.value)} /></Field>
        {save.isError && <ErrorState error={save.error} />}
        <Button onClick={() => save.mutate()} disabled={save.isPending}>Сохранить</Button>
      </Card>
    </section>
  );
}
