import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import WorkersPage from '@/app/(app)/workers/page';
import WorkerDetailPage from '@/app/(app)/workers/[id]/page';
import { mockFetch, renderWithProviders, signIn } from './helpers';

const push = vi.fn();
vi.mock('next/navigation', () => ({ useParams: () => ({ id: 'w1' }), useRouter: () => ({ push }), useSearchParams: () => new URLSearchParams() }));

const SUPER = { id: 's1', fullName: 'Owner', phone: '+998901112233', role: 'SUPER_ADMIN' as const, workerId: null, permissions: ['WORKER_VIEW_ALL', 'WORKER_APPROVE', 'WORKER_UPDATE', 'WORKER_DELETE', 'WORKER_ASSIGN_MANAGER'] };
const ADMIN = { ...SUPER, role: 'ADMIN' as const, permissions: ['WORKER_VIEW_ALL', 'WORKER_APPROVE', 'WORKER_UPDATE'] };
const worker = {
  id: 'w1', code: 'W-0007', fullName: 'Нигора Алиева', phone: '+998901234567', secondaryPhone: null, status: 'ACTIVE',
  latitude: null, longitude: null, locationReceivedAt: null, balance: '0', manager: null, collateral: null, collaterals: [],
  createdAt: '2026-09-23T00:00:00Z', updatedAt: '2026-09-23T00:00:00Z',
};

describe('«Мастерицы»: add by invitation link, delete for good', () => {
  it('«+ Добавить мастерицу» -> name + phone -> a Telegram link to copy or share', async () => {
    signIn(SUPER);
    const fetchMock = mockFetch({
      '/auth/me': SUPER, '/managers': { items: [] },
      '/workers/invitations': { id: 'i1', fullName: 'Нигора Алиева', phone: '+998901234567', createdAt: '2026-09-28T00:00:00Z', expiresAt: '2026-10-05T00:00:00Z', url: 'https://t.me/diamora1_bot?start=inv_abc' },
      '/workers': { items: [], nextCursor: null },
    });
    renderWithProviders(<WorkersPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: '+ Добавить мастерицу' }));
    await user.type(screen.getByLabelText('Фамилия и имя'), 'Нигора Алиева');
    await user.clear(screen.getByLabelText('Телефон'));
    await user.type(screen.getByLabelText('Телефон'), '+998901234567');
    await user.click(screen.getByRole('button', { name: 'Получить ссылку' }));

    expect(await screen.findByText('https://t.me/diamora1_bot?start=inv_abc')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Скопировать' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Отправить в Telegram' })).toBeInTheDocument();
    const post = fetchMock.mock.calls.find(([u, init]) => String(u).includes('/workers/invitations') && init?.method === 'POST');
    expect(JSON.parse(String(post![1]!.body))).toMatchObject({ fullName: 'Нигора Алиева', phone: '+998901234567', managerId: null });
  });

  it('delete: confirm -> DELETE -> back to the list', async () => {
    signIn(SUPER);
    const fetchMock = mockFetch({ '/auth/me': SUPER, '/managers': { items: [] }, '/workers/w1': worker, '/admin/assignments': { items: [], nextCursor: null } });
    renderWithProviders(<WorkerDetailPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Удалить мастерицу' }));
    expect(fetchMock.mock.calls.some(([, init]) => init?.method === 'DELETE')).toBe(false); // never before the confirm
    await user.click(screen.getByRole('button', { name: 'Удалить навсегда' }));
    await waitFor(() => expect(fetchMock.mock.calls.some(([u, init]) => String(u).endsWith('/workers/w1') && init?.method === 'DELETE')).toBe(true));
    await waitFor(() => expect(push).toHaveBeenCalledWith('/workers'));
  });

  it('delete refused (HAS_HISTORY): a plain explanation and «Архивировать» instead, never a raw code', async () => {
    signIn(SUPER);
    const routes = { '/auth/me': SUPER, '/managers': { items: [] }, '/workers/w1': worker, '/admin/assignments': { items: [], nextCursor: null } };
    const fetchMock = mockFetch(routes);
    fetchMock.mockImplementation(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      if (init?.method === 'DELETE') return new Response(JSON.stringify({ error: { code: 'HAS_HISTORY', message: 'x', details: { reasons: ['MONEY'] } } }), { status: 409, headers: { 'Content-Type': 'application/json' } });
      const path = new URL(url).pathname.replace(/^\/v1/, '');
      const hit = Object.entries(routes).find(([k]) => path === k || path.startsWith(k));
      return new Response(JSON.stringify(hit ? hit[1] : {}), { status: 200, headers: { 'Content-Type': 'application/json' } });
    });
    renderWithProviders(<WorkerDetailPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Удалить мастерицу' }));
    await user.click(screen.getByRole('button', { name: 'Удалить навсегда' }));
    expect(await screen.findByText(/Удалить нельзя/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Архивировать' })).toBeInTheDocument();
    expect(screen.queryByText('HAS_HISTORY')).not.toBeInTheDocument();
  });

  it('without WORKER_DELETE there is no delete button; without WORKER_APPROVE no add button', async () => {
    signIn(ADMIN);
    mockFetch({ '/auth/me': ADMIN, '/workers/w1': worker, '/admin/assignments': { items: [], nextCursor: null } });
    renderWithProviders(<WorkerDetailPage />);
    await screen.findByText('Нигора Алиева');
    expect(screen.queryByRole('button', { name: 'Удалить мастерицу' })).not.toBeInTheDocument();
  });
});
