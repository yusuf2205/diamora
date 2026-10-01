'use client';

import { useQuery } from '@tanstack/react-query';
import { PlayCircle } from 'lucide-react';
import { useState } from 'react';
import { useAuth } from '@/lib/auth';
import { EmptyState, ListSkeleton, PageHeader } from '@/components/ui';
import { fetchTutorials, type Tutorial, VideoModal } from '@/components/tutorials';

type Lang = 'uz' | 'ru';
const ROLE: Record<string, string> = { SUPER_ADMIN: 'Главный админ', ADMIN: 'Админ', MANAGER: 'Менеджер', WORKER: 'Мастерица', CUSTOMER: 'Покупатель' };


/** «Обучение»: short videos for each role, in Uzbek or Russian. The SUPER_ADMIN sees every one (to share them). */
export default function LearnPage() {
  const { me } = useAuth();
  const [lang, setLang] = useState<Lang>('ru');
  const [open, setOpen] = useState<Tutorial | null>(null);
  const q = useQuery({ queryKey: ['tutorials'], queryFn: fetchTutorials, staleTime: 60_000 });
  const mine = (q.data ?? []).filter((t) => me?.role === 'SUPER_ADMIN' || t.roles.includes(me?.role ?? ''));
  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader title="Обучение" subtitle="Короткие видео: как работать в Diamoraa — для каждой роли отдельно."
        actions={
          <div className="inline-flex overflow-hidden rounded-lg border border-border">
            {(['uz', 'ru'] as const).map((l) => (
              <button key={l} type="button" onClick={() => setLang(l)} aria-pressed={lang === l}
                className={`px-4 py-2 text-sm font-semibold ${lang === l ? 'bg-primary text-white' : 'hover:bg-border/40'}`}>{l === 'uz' ? "O'zbekcha" : 'Русский'}</button>
            ))}
          </div>
        } />
      {q.isLoading && <ListSkeleton rows={3} />}
      {q.data && !mine.length && <EmptyState title="Видео пока нет" hint="Загляните позже" />}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {mine.map((t) => (
          <button key={t.id} type="button" onClick={() => setOpen(t)} className="overflow-hidden rounded-2xl border border-border bg-card text-left transition hover:border-primary/50 hover:shadow-lg">
            <div className="relative aspect-video bg-border/40">
              {t.poster && <img src={t.poster} alt="" className="h-full w-full object-cover object-top" loading="lazy" />}
              <PlayCircle size={56} className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 text-white drop-shadow-lg" aria-hidden />
            </div>
            <div className="p-3">
              <p className="font-semibold">{t.title[lang] ?? t.title.ru}</p>
              <p className="text-xs text-muted">{t.roles.map((r) => ROLE[r] ?? r).join(', ')}{t.seconds ? ` · ${Math.ceil(t.seconds / 60)} мин` : ''}</p>
            </div>
          </button>
        ))}
      </div>
      {open && <VideoModal title={open.title[lang] ?? open.title.ru} src={open.files[lang] ?? open.files.ru} onClose={() => setOpen(null)} />}
    </div>
  );
}
