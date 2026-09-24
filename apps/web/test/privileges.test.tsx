import { fireEvent, screen, waitFor } from '@testing-library/react';
import { NextRequest } from 'next/server';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import ProfilePage from '@/app/(app)/profile/page';
import UserDetailPage from '@/app/(app)/team/[id]/page';
import { proxy } from '@/proxy';
import { errorResponse, mockFetch, renderWithProviders, signIn } from './helpers';

vi.mock('next/navigation', () => ({ useParams: () => ({ id: 'a1' }), useRouter: () => ({ push: vi.fn(), replace: vi.fn() }) }));

const OWNER = { id: 'sa1', fullName: 'Owner', phone: '+998901112233', role: 'SUPER_ADMIN' as const, workerId: null, permissions: ['USER_VIEW_ALL', 'USER_UPDATE', 'USER_DEACTIVATE', 'ROLE_ASSIGN', 'PERMISSION_MANAGE', 'LIVE_LOCATION_VIEW_ALL'] };
const manager = { id: 'a1', phone: '+998907001122', fullName: 'Manager One', role: 'MANAGER', status: 'ACTIVE', online: false, lastSeenAt: null, lastLoginAt: null, workerId: null, permissions: [], createdAt: '2026-09-10T10:00:00Z', locationHidden: false, permissionDetail: { role: 'MANAGER', defaults: [], effective: [], granted: [], revoked: [] } };
const sent = (fetch: ReturnType<typeof mockFetch>, method: string, path: string) =>
  fetch.mock.calls.filter(([u, i]) => String(u).includes(path) && (i as RequestInit | undefined)?.method === method).map(([, i]) => JSON.parse(String((i as RequestInit).body)));

describe('«Мой профиль»: change my own password', () => {
  beforeEach(() => signIn(OWNER));

  it('a wrong current password is said plainly (and never signs me out)', async () => {
    mockFetch({ '/auth/me': OWNER, '/auth/change-password': errorResponse(400, { error: { code: 'WRONG_PASSWORD', message: 'Current password is wrong' } }) });
    renderWithProviders(<ProfilePage />);
    fireEvent.change(await screen.findByLabelText('Текущий пароль'), { target: { value: 'old-one' } });
    fireEvent.change(screen.getByLabelText('Новый пароль'), { target: { value: 'New-Pass-123' } });
    fireEvent.change(screen.getByLabelText('Новый пароль ещё раз'), { target: { value: 'New-Pass-123' } });
    fireEvent.click(screen.getByRole('button', { name: 'Сменить пароль' }));
    expect(await screen.findByText('Текущий пароль неверный')).toBeInTheDocument();
  });

  it('the button stays off until the two new passwords match', async () => {
    mockFetch({ '/auth/me': OWNER });
    renderWithProviders(<ProfilePage />);
    fireEvent.change(await screen.findByLabelText('Текущий пароль'), { target: { value: 'old-one' } });
    fireEvent.change(screen.getByLabelText('Новый пароль'), { target: { value: 'New-Pass-123' } });
    fireEvent.change(screen.getByLabelText('Новый пароль ещё раз'), { target: { value: 'New-Pass-124' } });
    expect(screen.getByText('Пароли не совпадают')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Сменить пароль' })).toBeDisabled();
  });
});

describe('user card: the SUPER_ADMIN sets a chosen password and decides map visibility', () => {
  beforeEach(() => signIn(OWNER));

  it('«Задать пароль» sends exactly the typed password after confirming', async () => {
    const fetch = mockFetch({ '/users/a1/reset-password': { passwordSet: true }, '/auth/me': OWNER, '/users/a1': manager, '/permissions': { permissions: [], roleDefaults: {}, grantable: {} } });
    renderWithProviders(<UserDetailPage />);
    fireEvent.change(await screen.findByLabelText('Новый пароль'), { target: { value: 'Chosen-Pass-1' } });
    fireEvent.click(screen.getByRole('button', { name: 'Задать пароль' }));
    fireEvent.click(await screen.findByRole('button', { name: 'Подтвердить' }));
    await waitFor(() => expect(sent(fetch, 'POST', '/users/a1/reset-password')).toEqual([{ password: 'Chosen-Pass-1' }]));
  });

  it('unticking «Показывать на карте» hides the person from everyone else', async () => {
    const fetch = mockFetch({ '/users/a1/location-visibility': { ...manager, locationHidden: true }, '/auth/me': OWNER, '/users/a1': manager, '/permissions': { permissions: [], roleDefaults: {}, grantable: {} } });
    renderWithProviders(<UserDetailPage />);
    const sw = await screen.findByRole('switch', { name: 'Показывать на карте' });
    expect(sw).toHaveAttribute('aria-checked', 'true');
    fireEvent.click(sw);
    await waitFor(() => expect(sent(fetch, 'PUT', '/users/a1/location-visibility')).toEqual([{ hidden: true }]));
  });
});

describe('two front doors: diamoraa.uz for workers, the panel on its own host', () => {
  afterEach(() => { delete process.env.ADMIN_HOST; });
  const at = (url: string) => proxy(new NextRequest(url, { headers: { host: new URL(url).host } }));

  it('without ADMIN_HOST nothing moves (nobody is locked out before the subdomain exists)', () => {
    expect(at('https://diamoraa.uz/dashboard').headers.get('location')).toBeNull();
  });

  it('with ADMIN_HOST: the main domain keeps the landing and the Telegram page, the panel moves to its host', () => {
    process.env.ADMIN_HOST = 'admin.diamoraa.uz';
    expect(at('https://diamoraa.uz/').headers.get('location')).toBeNull();
    expect(at('https://diamoraa.uz/app/auth/telegram?t=x').headers.get('location')).toBeNull();
    expect(at('https://diamoraa.uz/workers?status=ACTIVE').headers.get('location')).toBe('https://admin.diamoraa.uz/workers?status=ACTIVE');
    expect(at('https://admin.diamoraa.uz/').headers.get('location')).toBe('https://admin.diamoraa.uz/dashboard');
    expect(at('https://admin.diamoraa.uz/login').headers.get('location')).toBeNull();
  });
});
