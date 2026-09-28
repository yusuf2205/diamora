import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import CollateralsPage from '@/app/(app)/collaterals/page';
import { mockFetch, renderWithProviders, signIn } from './helpers';

vi.mock('next/navigation', () => ({ useParams: () => ({}), useRouter: () => ({ push: vi.fn() }), useSearchParams: () => new URLSearchParams(), usePathname: () => '/' }));

const ADMIN = { id: 'a1', fullName: 'Admin', phone: '+998901112233', role: 'ADMIN' as const, workerId: null, permissions: ['WORKER_VIEW_ALL', 'COLLATERAL_VIEW', 'COLLATERAL_MANAGE'] };
const held = {
  id: 'c1', code: 'COL-1', type: 'MONEY', status: 'HELD', amount: '1500000', description: null, estimatedValue: null, storageLocation: 'Сейф',
  declaredAt: '2026-09-01T00:00:00Z', receivedAt: '2026-09-02T00:00:00Z', returnedAt: null, returnNote: null, worker: { id: 'w1', code: 'W-0001', fullName: 'Нигора' },
};

describe('«Залоги»: who gave what, what is with us, «Вернуть»', () => {
  it('shows the total in our hands; «Вернуть» needs a note and her confirmation, then POSTs the return', async () => {
    signIn(ADMIN);
    const fetchMock = mockFetch({
      '/auth/me': ADMIN, '/collaterals/c1/return': { ok: true },
      '/collaterals': { items: [held], nextCursor: null, held: { moneyTotal: '1500000', moneyCount: 1, itemCount: 0 } },
    });
    renderWithProviders(<CollateralsPage />);
    const user = userEvent.setup();
    expect(await screen.findAllByText(/Деньги: 1\s500\s000 сум/)).not.toHaveLength(0);
    await user.click((await screen.findAllByRole('button', { name: 'Вернуть' }))[0]);
    const submit = screen.getByRole('button', { name: 'Вернуть залог' });
    expect(submit).toBeDisabled();
    await user.type(screen.getByLabelText('Как вернули'), 'Отдали в руки');
    await user.click(screen.getByLabelText('Мастерица получила залог обратно'));
    await user.click(submit);
    await waitFor(() => {
      const post = fetchMock.mock.calls.find(([u, init]) => String(u).includes('/collaterals/c1/return') && init?.method === 'POST');
      expect(JSON.parse(String(post![1]!.body))).toEqual({ note: 'Отдали в руки', workerConfirmed: true });
    });
  });
});
