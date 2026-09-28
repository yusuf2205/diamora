'use client';

import { Download, X } from 'lucide-react';
import { useEffect, useState } from 'react';

interface BeforeInstallPromptEvent extends Event { prompt: () => Promise<void>; userChoice: Promise<{ outcome: string }> }

/**
 * «Добавить на экран»: one button puts Diamoraa on the phone's home screen like an app (Chrome/Android: the browser's own
 * install dialog; iPhone Safari has no such API, so we say in two words where the button is).
 */
export function InstallButton() {
  const [prompt, setPrompt] = useState<BeforeInstallPromptEvent | null>(null);
  const [ios, setIos] = useState(false);
  const [hidden, setHidden] = useState(true);

  useEffect(() => {
    const standalone = window.matchMedia('(display-mode: standalone)').matches || (navigator as unknown as { standalone?: boolean }).standalone === true;
    let dismissed = false;
    try { dismissed = localStorage.getItem('diamoraa.installDismissed') === '1'; } catch { /* private mode */ }
    if (standalone || dismissed) return;
    const onPrompt = (e: Event) => { e.preventDefault(); setPrompt(e as BeforeInstallPromptEvent); setHidden(false); };
    window.addEventListener('beforeinstallprompt', onPrompt);
    if (/iphone|ipad|ipod/i.test(navigator.userAgent)) { setIos(true); setHidden(false); }
    return () => window.removeEventListener('beforeinstallprompt', onPrompt);
  }, []);

  if (hidden) return null;
  const dismiss = () => { setHidden(true); try { localStorage.setItem('diamoraa.installDismissed', '1'); } catch { /* ignore */ } };
  return (
    <div className="flex items-center gap-2 bg-primary px-4 py-2 text-white">
      <Download size={20} aria-hidden />
      {prompt ? (
        <button className="flex-1 text-left text-sm font-bold" onClick={async () => { await prompt.prompt(); await prompt.userChoice; setHidden(true); }}>
          Добавить Diamoraa на экран телефона
        </button>
      ) : (
        <span className="flex-1 text-sm font-semibold">{ios ? 'Нажмите «Поделиться» → «На экран Домой»' : 'Добавьте Diamoraa на экран'}</span>
      )}
      <button aria-label="Закрыть" onClick={dismiss}><X size={18} /></button>
    </div>
  );
}
