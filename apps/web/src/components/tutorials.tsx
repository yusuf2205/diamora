'use client';

import { X } from 'lucide-react';

export interface Tutorial { id: string; roles: string[]; title: Record<string, string>; files: Record<string, string>; poster?: string; seconds?: number }

/** the manifest written by tools/tutorials/publish.sh, served next to the APK (any host, no account) */
export const fetchTutorials = () =>
  fetch('/download/tutorials/tutorials.json', { cache: 'no-store' }).then((r) => (r.ok ? r.json() : { items: [] })).then((d: { items: Tutorial[] }) => d.items);

/** A training video, big, on a dark backdrop; a click outside closes it. */
export function VideoModal({ title, src, onClose }: { title: string; src: string; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-2 sm:p-6" onClick={onClose} role="dialog" aria-modal aria-label={title}>
      <div className="relative flex max-h-full w-full max-w-5xl flex-col" onClick={(e) => e.stopPropagation()}>
        <div className="mb-2 flex items-center justify-between gap-3 text-white">
          <p className="font-semibold">{title}</p>
          <button type="button" onClick={onClose} aria-label="Закрыть" className="grid h-10 w-10 place-items-center rounded-full hover:bg-white/15"><X size={22} /></button>
        </div>
        <video src={src} controls autoPlay playsInline className="max-h-[85vh] w-full rounded-xl bg-black" />
      </div>
    </div>
  );
}
