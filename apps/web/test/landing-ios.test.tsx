import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

let ua = '';
vi.mock('next/headers', () => ({ headers: async () => new Headers({ 'user-agent': ua }) }));

import Landing from '@/app/page';

/** diamoraa.uz: an iPhone gets the web version as THE button (no Android app for it; owner, 2026-10-11). */
describe('landing', () => {
  it('iPhone: «Открыть Diamoraa» opens the web version; the APK is only a small link', async () => {
    ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 Version/17.5 Mobile/15E148 Safari/604.1';
    render(await Landing());
    expect(screen.getByRole('link', { name: /Открыть Diamoraa/ })).toHaveAttribute('href', '/w');
    expect(screen.queryByRole('link', { name: /^Скачать приложение$/ })).toHaveAttribute('href', '/download');
    expect(screen.getByText(/На экран „Домой“/)).toBeInTheDocument();
  });

  it('Android: the download is the big button, the web version under it', async () => {
    ua = 'Mozilla/5.0 (Linux; Android 13; SM-A145F) AppleWebKit/537.36 Chrome/126.0 Mobile Safari/537.36';
    render(await Landing());
    expect(screen.getByRole('link', { name: /Скачать приложение/ })).toHaveAttribute('href', '/download');
    expect(screen.getByRole('link', { name: /Открыть веб-версию/ })).toHaveAttribute('href', '/w');
  });
});
