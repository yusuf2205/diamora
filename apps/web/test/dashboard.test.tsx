import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import DashboardPage from '@/app/(app)/dashboard/page';
import { errorResponse, mockFetch, renderWithProviders, signIn } from './helpers';

const push = vi.fn();
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push }),
  useSearchParams: () => new URLSearchParams(),
}));

const SUPER_ADMIN = {
  id: 'sa1', fullName: 'Owner', phone: '+998901112233', role: 'SUPER_ADMIN' as const, workerId: null,
  permissions: ['ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_CREATE', 'WORKER_VIEW_ALL', 'FINANCE_VIEW_ALL', 'USER_VIEW_ALL', 'CATALOG_VIEW', 'INVENTORY_VIEW'],
};
const MANAGER = {
  id: 'm1', fullName: 'Manager', phone: '+998901112244', role: 'MANAGER' as const, workerId: null,
  permissions: ['ASSIGNMENT_VIEW_ASSIGNED', 'WORKER_VIEW_ASSIGNED', 'FINANCE_VIEW_ASSIGNED'], // no create, no USER_VIEW_ALL/CATALOG_VIEW/INVENTORY_VIEW
};

const fullDashboard = (over: Record<string, unknown> = {}) => ({
  workers: { total: 12, active: 10, withActiveAssignment: 6, withoutActiveAssignment: 4 },
  users: { superAdmins: 1, admins: 2, managers: 1, online: 3 },
  catalog: { published: 5, draft: 2 },
  work: { activeAssignments: 6, inProgress: 3, metersOnHand: 45, toDeliver: 2, toPickup: 1, needsAcceptance: 1, completed: 20, overdue: 0 },
  finance: { earned: '1500000', paid: '1000000', due: '500000', salesRevenue: null, expenses: null, netProfit: null },
  materials: { lowStock: 2, outOfStock: 1 },
  ...over,
});

describe('admin dashboard (§31): every card is real data, and either links to its exact filter or stays a plain stat', () => {
  it('renders real counters for every section a SUPER_ADMIN can see', async () => {
    signIn(SUPER_ADMIN);
    mockFetch({ '/auth/me': SUPER_ADMIN, '/dashboard': fullDashboard() });
    renderWithProviders(<DashboardPage />);
    expect(await screen.findByText('12')).toBeInTheDocument(); // workers.total
    expect(screen.getByText('20')).toBeInTheDocument(); // work.completed
    expect(screen.getByText('1 500 000 сум')).toBeInTheDocument(); // finance.earned, formatted
    expect(screen.getByText('Требуют приёмки')).toBeInTheDocument();
  });

  it('a zero count renders as an honest "0", never blank', async () => {
    signIn(SUPER_ADMIN);
    mockFetch({ '/auth/me': SUPER_ADMIN, '/dashboard': fullDashboard({ work: { activeAssignments: 0, inProgress: 0, metersOnHand: 0, toDeliver: 0, toPickup: 0, needsAcceptance: 0, completed: 0, overdue: 0 } }) });
    renderWithProviders(<DashboardPage />);
    await screen.findByText('Задания');
    const card = screen.getByText('Нужно доставить').closest('a');
    expect(card?.textContent).toContain('0');
  });

  it('a status card links straight to the pre-filtered assignments list', async () => {
    signIn(SUPER_ADMIN);
    mockFetch({ '/auth/me': SUPER_ADMIN, '/dashboard': fullDashboard() });
    renderWithProviders(<DashboardPage />);
    await screen.findByText('Задания');
    expect(screen.getByText('Нужно доставить').closest('a')).toHaveAttribute('href', '/assignments?status=READY_TO_DELIVER');
    expect(screen.getByText('Есть что забрать').closest('a')).toHaveAttribute('href', '/assignments?status=READY_FOR_PICKUP');
    expect(screen.getByText('Требуют приёмки').closest('a')).toHaveAttribute('href', '/assignments?status=UNDER_REVIEW');
    expect(screen.getByText('Закрыто').closest('a')).toHaveAttribute('href', '/assignments?status=COMPLETED');
    expect(screen.getByText('Всего').closest('a')).toHaveAttribute('href', '/workers');
  });

  it('an aggregate with no single matching filter is a plain stat, never a dead link', async () => {
    signIn(SUPER_ADMIN);
    mockFetch({ '/auth/me': SUPER_ADMIN, '/dashboard': fullDashboard() });
    renderWithProviders(<DashboardPage />);
    const workSection = (await screen.findByText('Задания')).closest('section')!;
    expect(within(workSection).getByText('Активных').closest('a')).toBeNull();
    expect(within(workSection).getByText('Просрочено').closest('a')).toBeNull();
    expect(within(workSection).getByText('Метров на руках').closest('a')).toBeNull();
  });

  it('shows a loading skeleton, then replaces it with real content', async () => {
    signIn(SUPER_ADMIN);
    mockFetch({ '/auth/me': SUPER_ADMIN, '/dashboard': fullDashboard() });
    const { container } = renderWithProviders(<DashboardPage />);
    expect(container.querySelectorAll('.animate-pulse').length).toBeGreaterThan(0);
    await screen.findByText('Задания');
    expect(container.querySelectorAll('.animate-pulse').length).toBe(0);
  });

  it('a failed load shows a human message with a working Retry, never a raw error code', async () => {
    signIn(SUPER_ADMIN);
    const fetchMock = mockFetch({ '/auth/me': SUPER_ADMIN, '/dashboard': errorResponse(500, { error: { code: 'INTERNAL', message: 'Internal server error' } }) });
    renderWithProviders(<DashboardPage />);
    expect(await screen.findByText('Не удалось выполнить действие')).toBeInTheDocument();
    expect(screen.queryByText(/INTERNAL/)).not.toBeInTheDocument();
    expect(screen.queryByText(/Internal server error/)).not.toBeInTheDocument();

    const before = fetchMock.mock.calls.filter((c) => String(c[0]).includes('/dashboard')).length;
    await userEvent.setup().click(screen.getByRole('button', { name: 'Повторить' }));
    await waitFor(() => expect(fetchMock.mock.calls.filter((c) => String(c[0]).includes('/dashboard')).length).toBeGreaterThan(before));
  });

  it('a MANAGER sees only the sections their permissions allow, scoped to their own workers', async () => {
    signIn(MANAGER);
    mockFetch({
      '/auth/me': MANAGER,
      '/dashboard': fullDashboard({ users: null, catalog: null, materials: null, workers: { total: 3, active: 3, withActiveAssignment: 1, withoutActiveAssignment: 2 } }),
    });
    renderWithProviders(<DashboardPage />);
    await screen.findByText('Задания');
    expect(screen.getByText('Мастерицы', { selector: 'h2' })).toBeInTheDocument();
    expect(screen.getByText('Финансы', { selector: 'h2' })).toBeInTheDocument();
    expect(screen.queryByText('Команда', { selector: 'h2' })).not.toBeInTheDocument();
    expect(screen.queryByText('Каталог', { selector: 'h2' })).not.toBeInTheDocument();
    expect(screen.queryByText('Материалы', { selector: 'h2' })).not.toBeInTheDocument();
    // no ASSIGNMENT_CREATE: the quick action must not be offered
    expect(screen.queryByRole('button', { name: 'Выдать работу' })).not.toBeInTheDocument();
  });

  it('"Выдать работу" opens the real create dialog for a user who may create assignments', async () => {
    signIn(SUPER_ADMIN);
    mockFetch({
      '/auth/me': SUPER_ADMIN, '/dashboard': fullDashboard(),
      '/workers': { items: [], nextCursor: null }, '/admin/catalog': { items: [], nextCursor: null }, '/admin/kits': { items: [] },
      '/settings/pay-rate': { ratePerKit: '30000', kitMeters: 9, updatedAt: '2026-01-01T00:00:00Z' },
    });
    renderWithProviders(<DashboardPage />);
    await userEvent.setup().click(await screen.findByRole('button', { name: '+ Выдать работу' }));
    expect(await screen.findByRole('heading', { name: 'Выдать работу' })).toBeInTheDocument();
  });
});
