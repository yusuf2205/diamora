'use client';

import QRCode from 'qrcode';
import { useEffect, useState } from 'react';
import { Button, Card } from '@/components/ui';

const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);

/** The QR of an assignment / worker, shown on screen and printable as an 80 × 60 mm label (the same code staff and the
 * worker scan at the handoff). Rendered locally from the opaque code: nothing about the person is encoded in it. */
export function QrCard({ code, title, lines = [], heading }: { code: string; title: string; lines?: string[]; heading: string }) {
  const [svg, setSvg] = useState<string | null>(null);
  useEffect(() => {
    let alive = true;
    QRCode.toString(code, { type: 'svg', margin: 1, errorCorrectionLevel: 'M' }).then((s) => { if (alive) setSvg(s); }).catch(() => setSvg(null));
    return () => { alive = false; };
  }, [code]);

  const print = () => {
    if (!svg) return;
    const w = window.open('', '_blank', 'width=480,height=420');
    if (!w) return;
    w.document.write(`<!doctype html><html><head><meta charset="utf-8"><title>QR ${esc(title)}</title>
<style>
  @page { size: 80mm 60mm; margin: 4mm; }
  body { margin: 0; font-family: Manrope, system-ui, sans-serif; }
  .label { display: flex; align-items: center; gap: 4mm; width: 72mm; height: 52mm; }
  .qr { width: 44mm; height: 44mm; flex: none; } .qr svg { width: 100%; height: 100%; }
  .brand { font-size: 8pt; color: #666; font-weight: 800; } .title { font-size: 11pt; font-weight: 800; margin-top: 1mm; }
  .line { font-size: 9pt; margin-top: 1mm; }
</style></head><body><div class="label"><div class="qr">${svg}</div><div><div class="brand">Diamoraa</div>
<div class="title">${esc(title)}</div>${lines.map((l) => `<div class="line">${esc(l)}</div>`).join('')}</div></div>
<script>window.onload = () => { window.print(); setTimeout(() => window.close(), 300); };</script></body></html>`);
    w.document.close();
  };

  return (
    <Card>
      <h2 className="mb-2 text-sm font-semibold">{heading}</h2>
      <div className="flex flex-col items-center gap-3 sm:flex-row sm:items-center">
        {svg ? <div className="h-40 w-40 shrink-0 [&>svg]:h-full [&>svg]:w-full" aria-label={`QR ${title}`} dangerouslySetInnerHTML={{ __html: svg }} /> : <div className="h-40 w-40 animate-pulse rounded bg-border" />}
        <div className="min-w-0 text-center sm:text-left">
          <p className="font-medium">{title}</p>
          {lines.map((l) => <p key={l} className="text-sm text-muted">{l}</p>)}
          <Button className="mt-3" variant="outline" onClick={print} disabled={!svg}>Печать QR</Button>
        </div>
      </div>
    </Card>
  );
}
