import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import WorkerDetailPage from '@/app/(app)/workers/[id]/page';
import type { Me } from '@/lib/types';
import { mockFetch, renderWithProviders, signIn } from './helpers';

vi.mock('next/navigation', () => ({ useParams: () => ({ id: 'w1' }), useRouter: () => ({ push: vi.fn() }) }));

const ADMIN = { id: 'a1', fullName: 'Owner', phone: '+998901112233', role: 'ADMIN' as const, workerId: null, permissions: ['WORKER_VIEW_ALL', 'WORKER_APPROVE'] };
const MANAGER = { ...ADMIN, role: 'MANAGER' as const, permissions: ['WORKER_VIEW_ASSIGNED'] };

const pending = {
  id: 'w1', code: 'W-0003', fullName: 'Test', phone: '+998994390531', secondaryPhone: null, status: 'PENDING_APPROVAL',
  latitude: null, longitude: null, locationReceivedAt: null, balance: '0', manager: null,
  collateral: { id: 'c1', type: 'MONEY', status: 'PENDING', amount: '100000', description: null },
  createdAt: '2026-09-23T00:00:00Z', updatedAt: '2026-09-23T00:00:00Z',
};

const routes = (me: Me) => ({
  '/workers/w1/approve': { ...pending, status: 'ACTIVE' },
  '/workers/w1/reject': { ...pending, status: 'REJECTED' },
  '/auth/me': me,
  '/workers/w1': pending,
  '/admin/assignments': { items: [], nextCursor: null },
});

describe('worker approval on the web panel: the same decision the mobile ADMIN app offers', () => {
  it('approve: confirms, sends collateralReceived, and never before the confirm', async () => {
    signIn(ADMIN);
    const fetchMock = mockFetch(routes(ADMIN));
    renderWithProviders(<WorkerDetailPage />);
    const user = userEvent.setup();

    await user.click(await screen.findByRole('button', { name: 'Одобрить' }));
    expect(fetchMock.mock.calls.some(([u]) => String(u).includes('/approve'))).toBe(false);
    await user.click(screen.getByLabelText('Залог получен'));
    await user.click(screen.getAllByRole('button', { name: 'Одобрить' }).at(-1)!);

    await waitFor(() => {
      const call = fetchMock.mock.calls.find(([u]) => String(u).includes('/workers/w1/approve'));
      expect(call).toBeDefined();
      expect(JSON.parse(String(call![1]!.body))).toEqual({ collateralReceived: true });
    });
  });

  it('reject: needs a real reason before the button enables, then sends it', async () => {
    signIn(ADMIN);
    const fetchMock = mockFetch(routes(ADMIN));
    renderWithProviders(<WorkerDetailPage />);
    const user = userEvent.setup();

    await user.click(await screen.findByRole('button', { name: 'Отклонить' }));
    const confirm = screen.getAllByRole('button', { name: 'Отклонить' }).at(-1)!;
    expect(confirm).toBeDisabled();
    await user.type(screen.getByPlaceholderText('Причина (её увидит мастерица)'), 'Не подходит по условиям');
    await user.click(confirm);

    await waitFor(() => {
      const call = fetchMock.mock.calls.find(([u]) => String(u).includes('/workers/w1/reject'));
      expect(JSON.parse(String(call![1]!.body))).toEqual({ reason: 'Не подходит по условиям' });
    });
  });

  it('without WORKER_APPROVE (a MANAGER) the buttons are simply not there', async () => {
    signIn(MANAGER);
    mockFetch(routes(MANAGER));
    renderWithProviders(<WorkerDetailPage />);
    expect(await screen.findByText(/Test/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Одобрить' })).not.toBeInTheDocument();
  });
});
