import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import AppLayout from '@/app/(app)/layout';
import LoginPage from '@/app/login/page';
import { mockFetch, renderWithProviders, signIn } from './helpers';
import { push, replace } from './setup';

describe('SUPER_ADMIN login flow (M2 §21)', () => {
  it('submits phone + password and redirects to /dashboard on success', async () => {
    const fetchMock = mockFetch({
      '/auth/admin/login': { accessToken: 'a', refreshToken: 'r', user: { id: 'u1', fullName: 'Owner', phone: '+998901112233', role: 'SUPER_ADMIN', workerId: null, permissions: [] } },
    });
    renderWithProviders(<LoginPage />);
    await userEvent.type(screen.getByLabelText('Телефон'), '+998901112233');
    await userEvent.type(screen.getByLabelText('Пароль'), 'Sup3r-Secret!');
    await userEvent.click(screen.getByRole('button', { name: 'Войти' }));

    await waitFor(() => expect(replace).toHaveBeenCalledWith('/dashboard'));
    const call = fetchMock.mock.calls.find(([u]) => String(u).includes('/auth/admin/login'));
    expect(call).toBeTruthy();
  });

  it('shows a clear error on wrong credentials, never redirects', async () => {
    // mockFetch's helper always answers 200; this test needs a 401, so it stubs fetch directly.
    const fn = vi.fn(async () => new Response(JSON.stringify({ error: { code: 'INVALID_CREDENTIALS', message: 'Invalid' } }), { status: 401 }));
    vi.stubGlobal('fetch', fn);
    renderWithProviders(<LoginPage />);
    await userEvent.type(screen.getByLabelText('Телефон'), '+998901112233');
    await userEvent.type(screen.getByLabelText('Пароль'), 'wrong');
    await userEvent.click(screen.getByRole('button', { name: 'Войти' }));
    expect(await screen.findByText('Неверный телефон или пароль')).toBeInTheDocument();
    expect(replace).not.toHaveBeenCalled();
  });
});

describe('auth guard on the (app) layout — the server-defined permission set, never guessed on the client', () => {
  it('not signed in: redirected to /login, the panel content never renders', async () => {
    mockFetch({});
    renderWithProviders(<AppLayout><p>Секретные данные</p></AppLayout>);
    await waitFor(() => expect(replace).toHaveBeenCalledWith('/login'));
    expect(screen.queryByText('Секретные данные')).not.toBeInTheDocument();
  });

  it('a WORKER role is told the panel is for staff — never shown the admin nav (D-028)', async () => {
    signIn({ id: 'w1', fullName: 'Малика', phone: '+998900000000', role: 'WORKER', workerId: 'w1', permissions: [] });
    mockFetch({ '/auth/me': { id: 'w1', fullName: 'Малика', phone: '+998900000000', role: 'WORKER', workerId: 'w1', permissions: [] } });
    renderWithProviders(<AppLayout><p>Секретные данные</p></AppLayout>);
    expect(await screen.findByText(/для администраторов и менеджеров/)).toBeInTheDocument();
    expect(screen.queryByText('Секретные данные')).not.toBeInTheDocument();
  });

  it('role display + permission-scoped navigation: a MANAGER without USER_VIEW_ALL never sees "Команда"', async () => {
    signIn({ id: 'm1', fullName: 'Manager One', phone: '+998907001122', role: 'MANAGER', workerId: null, permissions: ['WORKER_VIEW_ASSIGNED'] });
    mockFetch({ '/auth/me': { id: 'm1', fullName: 'Manager One', phone: '+998907001122', role: 'MANAGER', workerId: null, permissions: ['WORKER_VIEW_ASSIGNED'] } });
    renderWithProviders(<AppLayout><p>Содержимое страницы</p></AppLayout>);
    expect(await screen.findByText('Содержимое страницы')).toBeInTheDocument();
    expect(screen.getByText('Менеджер')).toBeInTheDocument(); // role label shown in the sidebar
    expect(screen.getByText('Мастерицы')).toBeInTheDocument(); // WORKER_VIEW_ASSIGNED grants this
    expect(screen.queryByText('Команда')).not.toBeInTheDocument(); // no USER_VIEW_ALL
  });
});
