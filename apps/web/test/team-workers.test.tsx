import { screen, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import ManagersPage from '@/app/(app)/managers/page';
import TeamPage from '@/app/(app)/team/page';
import WorkersPage from '@/app/(app)/workers/page';
import { mockFetch, renderWithProviders, signIn } from './helpers';

const SUPER_ADMIN = { id: 'sa1', fullName: 'Owner', phone: '+998901112233', role: 'SUPER_ADMIN' as const, workerId: null, permissions: ['USER_VIEW_ALL', 'WORKER_VIEW_ALL'] };

describe('users page (Команда, M2 §21): roles are shown, not just names', () => {
  it('shows each user with a human role label', async () => {
    signIn(SUPER_ADMIN);
    mockFetch({
      '/auth/me': SUPER_ADMIN,
      '/users': {
        items: [
          { id: 'sa1', phone: '+998901112233', fullName: 'Owner', role: 'SUPER_ADMIN', status: 'ACTIVE', online: true, permissions: [] },
          { id: 'm1', phone: '+998907001122', fullName: 'Manager One', role: 'MANAGER', status: 'ACTIVE', online: false, permissions: [] },
        ],
      },
    });
    renderWithProviders(<TeamPage />);
    expect(await screen.findByText('Owner')).toBeInTheDocument();
    expect(screen.getByText('Главный администратор')).toBeInTheDocument(); // roleLabel(SUPER_ADMIN)
    expect(screen.getByText('Manager One')).toBeInTheDocument();
    expect(screen.getByRole('cell', { name: 'Менеджер' })).toBeInTheDocument(); // roleLabel(MANAGER), not the column header
  });

  it('a viewer without USER_VIEW_ALL is refused, never a partial table', async () => {
    signIn({ ...SUPER_ADMIN, role: 'MANAGER', permissions: [] });
    mockFetch({ '/auth/me': { ...SUPER_ADMIN, role: 'MANAGER', permissions: [] } });
    renderWithProviders(<TeamPage />);
    expect(await screen.findByText('Недостаточно прав для просмотра команды')).toBeInTheDocument();
    expect(screen.queryByRole('table')).not.toBeInTheDocument();
  });
});

describe('workers table (M2 §21): mirrors the mobile ADMIN list, same server scope', () => {
  it('renders a worker row with status, manager and balance', async () => {
    signIn(SUPER_ADMIN);
    mockFetch({
      '/auth/me': SUPER_ADMIN,
      '/workers': {
        items: [{
          id: 'w1', code: 'W-0001', fullName: 'Малика Каримова', phone: '+998901234567', secondaryPhone: null, status: 'ACTIVE',
          latitude: null, longitude: null, locationReceivedAt: null, balance: '450000',
          manager: { id: 'm1', fullName: 'Manager One' }, collateral: null, createdAt: '2026-01-01T00:00:00Z', updatedAt: '2026-01-01T00:00:00Z',
        }],
        nextCursor: null,
      },
    });
    renderWithProviders(<WorkersPage />);
    expect(await screen.findByText(/Малика Каримова/)).toBeInTheDocument();
    const row = within(screen.getByRole('table'));
    expect(row.getByText('Активна')).toBeInTheDocument(); // scoped: the status filter <select> also has this option text
    expect(row.getByText('Manager One')).toBeInTheDocument();
    expect(row.getByText('450 000 сум')).toBeInTheDocument();
  });
});

describe('managers page (M2 §21): a manager → her assigned workers, numbers computed server-side', () => {
  it('shows each manager\'s own worker count and earnings, never another manager\'s', async () => {
    signIn(SUPER_ADMIN);
    mockFetch({
      '/auth/me': SUPER_ADMIN,
      '/managers': {
        items: [{
          id: 'm1', fullName: 'Manager One', phone: '+998907001122', role: 'MANAGER', status: 'ACTIVE', online: true, permissions: [],
          stats: { workers: 3, activeWorkers: 2, activeAssignments: 1, metersOnHand: 9, toDeliver: 0, toPickup: 0, overdue: 0, earned: '270000', paid: '100000', due: '170000' },
        }],
      },
    });
    renderWithProviders(<ManagersPage />);
    expect(await screen.findByText('Manager One')).toBeInTheDocument();
    expect(screen.getByText('3')).toBeInTheDocument(); // her assigned worker count
    expect(screen.getByText('270 000 сум')).toBeInTheDocument(); // earned
    expect(screen.getByText('170 000 сум')).toBeInTheDocument(); // due
  });
});
