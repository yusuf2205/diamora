import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import FinancePage from '@/app/(app)/finance/page';
import RatingPage from '@/app/(app)/rating/page';
import SystemPage from '@/app/(app)/system/page';
import { mockFetch, renderWithProviders, signIn } from './helpers';

vi.mock('next/navigation', () => ({ useParams: () => ({}), useRouter: () => ({ push: vi.fn() }), useSearchParams: () => new URLSearchParams(), usePathname: () => '/' }));

const OWNER = { id: 's1', fullName: 'Owner', phone: '+998901112233', role: 'SUPER_ADMIN' as const, workerId: null, permissions: ['PROFIT_VIEW', 'WORKER_VIEW_ALL', 'SETTINGS_MANAGE'] };

describe('owner analytics pages', () => {
  it('«Прибыль»: months with profit; «+ Продажа» posts the typed amount', async () => {
    signIn(OWNER);
    const fetchMock = mockFetch({
      '/auth/me': OWNER,
      '/admin/finance/profit': { items: [{ month: '2026-09', sales: '1000000', labor: '300000', materials: '100000', expenses: '50000', profit: '550000', materialsWithoutPrice: 1 }] },
      '/admin/finance/sales': { items: [] }, '/admin/finance/expenses': { items: [] },
      '/admin/stock/value': { warehouse: '200000', withWorkers: '50000', total: '250000', withoutPrice: [{ id: 'm1', name: 'Нить' }] },
    });
    renderWithProviders(<FinancePage />);
    expect(await screen.findByText(/сен 2026/)).toBeInTheDocument();
    expect(screen.getByText(/550\s000 сум/)).toBeInTheDocument();
    expect(screen.getByText(/Без цены: Нить/)).toBeInTheDocument();
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: '+ Продажа' }));
    await user.type(screen.getByLabelText('Сумма, сум'), '1 200 000');
    await user.click(screen.getByRole('button', { name: 'Сохранить' }));
    await waitFor(() => {
      const post = fetchMock.mock.calls.find(([u, init]) => String(u).includes('/admin/finance/sales') && init?.method === 'POST');
      expect(JSON.parse(String(post![1]!.body)).total).toBe('1200000');
    });
  });

  it('«Рейтинг»: best first with the score', async () => {
    signIn(OWNER);
    mockFetch({ '/auth/me': OWNER, '/admin/reports/rating': { items: [{ worker: { id: 'w1', code: 'W-1', fullName: 'Нигора' }, acceptedMeters: 54, defectiveMeters: 0, defectRate: 0, works: 6, late: 0, withDeadline: 6, score: 92 }] } });
    renderWithProviders(<RatingPage />);
    expect((await screen.findAllByText('Нигора')).length).toBeGreaterThan(0);
    expect(screen.getAllByText('92').length).toBeGreaterThan(0);
  });

  it('«Состояние системы»: services and the last backup in words', async () => {
    signIn(OWNER);
    mockFetch({ '/auth/me': OWNER, '/admin/system/status': { now: new Date().toISOString(), version: '1.0.0', uptimeSeconds: 7200, database: { ok: true, ms: 3, size: '40 MB' }, redis: { ok: true, ms: 1 }, backupsVisible: true, backups: [{ job: 'pg_dump', ok: true, at: new Date().toISOString(), bytes: 5_000_000 }] } });
    renderWithProviders(<SystemPage />);
    expect(await screen.findByText('База данных (каждый день)')).toBeInTheDocument();
    expect(screen.getByText('в порядке')).toBeInTheDocument();
  });
});
