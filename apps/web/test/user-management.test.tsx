import { fireEvent, screen, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import TeamPage from '@/app/(app)/team/page';
import UserDetailPage from '@/app/(app)/team/[id]/page';
import { mockFetch, renderWithProviders, signIn } from './helpers';

const params = { id: 'a1' };
vi.mock('next/navigation', () => ({ useParams: () => params, useRouter: () => ({ push: vi.fn() }) }));

const SUPER_ADMIN = {
  id: 'sa1', fullName: 'Owner', phone: '+998901112233', role: 'SUPER_ADMIN' as const, workerId: null,
  permissions: ['USER_VIEW_ALL', 'USER_CREATE', 'USER_UPDATE', 'USER_DEACTIVATE', 'ROLE_ASSIGN', 'PERMISSION_MANAGE', 'AUDIT_VIEW'],
};
const DEFAULTS = ['WORKER_VIEW_ASSIGNED', 'ASSIGNMENT_VIEW_ASSIGNED', 'FINANCE_VIEW_ASSIGNED', 'MAP_VIEW_ASSIGNED', 'LIVE_LOCATION_VIEW_ASSIGNED'];
const GRANTABLE = ['COLLATERAL_VIEW', 'COLLATERAL_MANAGE', 'ASSIGNMENT_CREATE', 'ASSIGNMENT_ACCEPT', 'CASH_PAYOUT', 'CATALOG_VIEW', 'INVENTORY_VIEW', 'WORKER_UPDATE'];
const manager = (status = 'ACTIVE') => ({
  id: 'a1', phone: '+998907001122', fullName: 'Manager One', role: 'MANAGER', status, online: false, lastSeenAt: null, lastLoginAt: null,
  workerId: null, permissions: DEFAULTS, createdAt: '2026-09-10T10:00:00Z',
  permissionDetail: { role: 'MANAGER', defaults: DEFAULTS, effective: DEFAULTS, granted: [], revoked: [] },
});

function routes(extra: Record<string, unknown> = {}) {
  // more specific paths first: the mock matches by prefix, in insertion order
  return mockFetch({
    ...extra,
    '/auth/me': SUPER_ADMIN,
    '/users/a1': manager(),
    '/users': {
      items: [
        { id: 'sa1', phone: '+998901112233', fullName: 'Owner', role: 'SUPER_ADMIN', status: 'ACTIVE', online: true, permissions: [] },
        { id: 'u9', phone: '+998905550000', fullName: 'Малика Каримова', role: 'WORKER', status: 'ACTIVE', online: false, permissions: [], workerId: 'w9', managerName: 'Manager One' },
      ],
      nextCursor: null,
    },
    '/permissions': { permissions: [...DEFAULTS, ...GRANTABLE], roleDefaults: { MANAGER: DEFAULTS }, grantable: { MANAGER: GRANTABLE } },
    '/audit': { items: [{ id: 'l1', action: 'user.create', entity: 'User', entityId: 'a1', actorRole: 'SUPER_ADMIN', createdAt: '2026-09-10T10:00:00Z' }], nextCursor: null },
  });
}

const calls = (fetch: ReturnType<typeof mockFetch>, method: string, path: string) =>
  fetch.mock.calls.filter(([u, init]) => String(u).includes(path) && (init?.method ?? 'GET') === method).map(([, init]) => (init?.body ? JSON.parse(String(init.body)) : undefined));

describe('web «Команда»: filters, search, the worker row shows her manager', () => {
  beforeEach(() => signIn(SUPER_ADMIN));

  it('role / status filters and the search go to the server as query params', async () => {
    const fetch = routes();
    renderWithProviders(<TeamPage />);
    expect(await screen.findByText('Малика Каримова')).toBeInTheDocument();
    expect(screen.getByText('Manager One')).toBeInTheDocument(); // her manager column
    expect(screen.getByText(/это вы/)).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Менеджеры' }));
    await waitFor(() => expect(fetch.mock.calls.some(([u]) => String(u).includes('role=MANAGER'))).toBe(true));
    fireEvent.click(screen.getByRole('button', { name: 'Отключённые' }));
    await waitFor(() => expect(fetch.mock.calls.some(([u]) => String(u).includes('status=SUSPENDED'))).toBe(true));
    fireEvent.change(screen.getByLabelText('Поиск'), { target: { value: 'Мал' } });
    await waitFor(() => expect(fetch.mock.calls.some(([u]) => String(u).includes('q=%D0%9C%D0%B0%D0%BB'))).toBe(true));
  });
});

describe('web user card: role, rights in plain words, disable/restore', () => {
  beforeEach(() => signIn(SUPER_ADMIN));

  it('rights are human words (never codes); toggling one and saving sends grant/revoke against the role defaults', async () => {
    const fetch = routes({ '/users/a1/permissions': manager() });
    renderWithProviders(<UserDetailPage />);
    expect(await screen.findByText('Выдавать работу')).toBeInTheDocument();
    expect(screen.queryByText('ASSIGNMENT_CREATE')).not.toBeInTheDocument();
    expect(screen.queryByText('Видеть всех мастериц')).not.toBeInTheDocument(); // never grantable to a MANAGER
    expect(screen.getAllByText('Создан(а)')).toHaveLength(2); // the fact row + the history entry
    fireEvent.click(screen.getByLabelText(/Выдавать работу/));
    fireEvent.click(screen.getByRole('button', { name: 'Сохранить' }));
    await waitFor(() => expect(calls(fetch, 'PUT', '/users/a1/permissions')).toEqual([{ grant: ['ASSIGNMENT_CREATE'], revoke: [] }]));
  });

  it('«Изменить роль» confirms naming both roles before calling the API', async () => {
    const fetch = routes({ '/users/a1/role': manager() });
    renderWithProviders(<UserDetailPage />);
    await screen.findByText('Manager One');
    fireEvent.click(screen.getByRole('button', { name: 'Администратор' }));
    fireEvent.click(screen.getByRole('button', { name: 'Изменить роль' }));
    expect(await screen.findByText(/с «Менеджер» на «Администратор»/)).toBeInTheDocument();
    expect(calls(fetch, 'PUT', '/users/a1/role')).toEqual([]);
    fireEvent.click(screen.getByRole('button', { name: 'Подтвердить' }));
    await waitFor(() => expect(calls(fetch, 'PUT', '/users/a1/role')).toEqual([{ role: 'ADMIN' }]));
  });

  it('«Отключить» asks first; a disabled user gets «Восстановить»', async () => {
    const fetch = routes({ '/users/a1/status': manager('SUSPENDED') });
    renderWithProviders(<UserDetailPage />);
    await screen.findByText('Manager One');
    fireEvent.click(screen.getByRole('button', { name: 'Отключить пользователя' }));
    expect(await screen.findByText(/Вся история сохранится/)).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Подтвердить' }));
    await waitFor(() => expect(calls(fetch, 'POST', '/users/a1/status')).toEqual([{ status: 'SUSPENDED' }]));
  });

  it('my own card has no role change and no disable', async () => {
    params.id = 'sa1';
    routes({ '/users/sa1': { ...manager(), id: 'sa1', fullName: 'Owner', role: 'SUPER_ADMIN', permissionDetail: { role: 'SUPER_ADMIN', defaults: [], effective: [], granted: [], revoked: [] } } });
    renderWithProviders(<UserDetailPage />);
    expect(await screen.findByText('У главного администратора есть все права. Их нельзя ограничить.')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Изменить роль' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Отключить пользователя' })).not.toBeInTheDocument();
    params.id = 'a1';
  });
});
