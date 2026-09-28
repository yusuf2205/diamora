import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import WorkerHome from '@/app/w/page';
import WorkerWebLogin from '@/app/w/login/page';
import { mockFetch, renderWithProviders, signIn } from './helpers';

const replace = vi.fn();
vi.mock('next/navigation', () => ({ useRouter: () => ({ replace, push: vi.fn() }), usePathname: () => '/w', useSearchParams: () => new URLSearchParams() }));

const WORKER = { id: 'u1', fullName: 'Малика', phone: '+998901234567', role: 'WORKER' as const, workerId: 'w1', permissions: [] };

describe('web version for workers (/w)', () => {
  it('login: «Войти через Telegram» opens the bot, then this tab polls and signs in by itself', async () => {
    let polls = 0;
    const fetchMock = mockFetch({});
    fetchMock.mockImplementation(async (input: RequestInfo | URL) => {
      const path = new URL(String(input)).pathname;
      if (path.endsWith('/auth/telegram/session')) return new Response(JSON.stringify({ deepLink: 'https://t.me/diamora1_bot?start=SECRETSESSIONTOKEN123', expiresAt: '2030-01-01T00:00:00Z' }), { status: 200 });
      if (path.endsWith('/auth/telegram/poll')) {
        polls++;
        return new Response(JSON.stringify(polls < 2 ? { status: 'WAITING' } : { accessToken: 'a', refreshToken: 'r' }), { status: 200 });
      }
      return new Response(JSON.stringify(WORKER), { status: 200 });
    });
    const assign = vi.fn();
    Object.defineProperty(window, 'location', { value: { ...window.location, set href(v: string) { assign(v); } }, writable: true });
    renderWithProviders(<WorkerWebLogin />);
    await userEvent.setup().click(screen.getByRole('button', { name: /Войти через Telegram/ }));
    expect(await screen.findByText(/нажмите «Старт»/)).toBeInTheDocument();
    expect(assign).toHaveBeenCalledWith(expect.stringContaining('tg://resolve?domain=diamora1_bot&start=SECRETSESSIONTOKEN123'));
    await waitFor(() => expect(replace).toHaveBeenCalledWith('/w'), { timeout: 8000 });
    const pollBody = JSON.parse(String(fetchMock.mock.calls.find(([u]) => String(u).includes('/poll'))![1]!.body));
    expect(pollBody).toMatchObject({ sessionToken: 'SECRETSESSIONTOKEN123', device: { platform: 'WEB' } });
  }, 15000);

  it('home: waiting work with «Сканировать QR» when the kit is at her door, money and her request', async () => {
    signIn(WORKER);
    mockFetch({
      '/auth/me': WORKER,
      '/work/current': {
        id: 'a1', status: 'READY_TO_DELIVER', kitCount: 2, plannedMeters: 18, reportedMeters: 0, expectedPayment: '60000', dueAt: null,
        product: { name: 'Oddiy tekis' }, color: { name: 'Pushti', hex: '#f4a6c0' }, materials: [{ materialId: 'm1', name: 'Органза', unit: 'METER', quantity: 18 }],
        handoff: { status: 'AWAITING_WORKER', expired: false },
      },
      '/work/earnings/monthly': { items: [] },
      '/work/earnings': { balance: '30000', earned: '90000', paid: '60000' },
      '/work/requests': { items: [{ id: 'r1', status: 'PENDING', meters: 18, product: { name: 'Oddiy tekis' }, color: { name: 'Pushti' }, decisionNote: null, createdAt: new Date().toISOString() }] },
      '/me/notifications': { unread: 1, items: [{ id: 'n1', title: 'Сотрудник передаёт вам комплект', body: null, read: false, createdAt: new Date().toISOString() }] },
    });
    renderWithProviders(<WorkerHome />);
    expect(await screen.findByText('Ваш комплект готов к получению')).toBeInTheDocument();
    expect(screen.getAllByText('Сканировать QR').length).toBeGreaterThanOrEqual(1);
    expect(screen.getByText('Заявка отправлена')).toBeInTheDocument();
    expect(screen.getByText('Выбрать работу')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Обновить прогресс' })).not.toBeInTheDocument(); // not received yet
  });
});
