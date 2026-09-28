import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import WorkersPage from '@/app/(app)/workers/page';
import AuditPage from '@/app/(app)/audit/page';
import { mockFetch, renderWithProviders, signIn } from './helpers';

vi.mock('next/navigation', () => ({ useParams: () => ({}), useRouter: () => ({ push: vi.fn() }), useSearchParams: () => new URLSearchParams(), usePathname: () => '/' }));

const OWNER = { id: 's1', fullName: 'Owner', phone: '+998901112233', role: 'SUPER_ADMIN' as const, workerId: null, permissions: ['WORKER_VIEW_ALL', 'WORKER_ASSIGN_MANAGER', 'AUDIT_VIEW'] };
const w = (id: string, fullName: string, manager: { id: string; fullName: string } | null) => ({
  id, code: `W-${id}`, fullName, phone: '+998900000000', secondaryPhone: null, status: 'ACTIVE', latitude: null, longitude: null, locationReceivedAt: null,
  balance: '0', manager, collateral: null, createdAt: '2026-09-01T00:00:00Z', updatedAt: '2026-09-01T00:00:00Z',
});
const MGR = { id: 'm1', fullName: 'Дилноза', phone: '+998901000000', status: 'ACTIVE', stats: { workers: 1 } };

describe('«Назначить менеджера» for several workers; «Очистить журнал»', () => {
  it('pick a manager, tick workers, one request with only the ones that change', async () => {
    signIn(OWNER);
    const fetchMock = mockFetch({
      '/auth/me': OWNER, '/managers': { items: [MGR] }, '/workers/manager-bulk': { changed: 1 },
      '/workers': { items: [w('1', 'Нигора', { id: 'm1', fullName: 'Дилноза' }), w('2', 'Юлдуз', null)], nextCursor: null },
    });
    renderWithProviders(<WorkersPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Назначить менеджера' }));
    await user.selectOptions(await screen.findByLabelText('Менеджер'), await screen.findByRole('option', { name: 'Дилноза · 1' }));
    await waitFor(() => expect(screen.getByRole('checkbox', { name: 'Нигора' })).toBeChecked()); // already hers
    await user.click(screen.getByRole('checkbox', { name: 'Юлдуз' }));
    await user.click(screen.getByRole('button', { name: 'Назначить (1)' }));
    await waitFor(() => {
      const post = fetchMock.mock.calls.find(([u, init]) => String(u).includes('/workers/manager-bulk') && init?.method === 'POST');
      expect(JSON.parse(String(post![1]!.body))).toEqual({ managerId: 'm1', workerIds: ['2'] });
    });
  });

  it('SUPER_ADMIN: «Очистить журнал» -> confirm -> POST /audit/clear', async () => {
    signIn(OWNER);
    const fetchMock = mockFetch({ '/auth/me': OWNER, '/audit/clear': { clearedAt: '2026-09-29T00:00:00Z' }, '/audit': { items: [], nextCursor: null } });
    renderWithProviders(<AuditPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Очистить журнал' }));
    expect(fetchMock.mock.calls.some(([u]) => String(u).includes('/audit/clear'))).toBe(false);
    await user.click(screen.getByRole('button', { name: 'Очистить' }));
    await waitFor(() => expect(fetchMock.mock.calls.some(([u, init]) => String(u).includes('/audit/clear') && init?.method === 'POST')).toBe(true));
  });
});
