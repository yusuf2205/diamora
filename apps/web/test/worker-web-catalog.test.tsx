import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import WorkerCatalog from '@/app/w/catalog/page';
import { mockFetch, renderWithProviders, signIn } from './helpers';

vi.mock('next/navigation', () => ({ useRouter: () => ({ replace: vi.fn(), push: vi.fn() }), usePathname: () => '/w/catalog', useSearchParams: () => new URLSearchParams() }));

const WORKER = { id: 'u1', fullName: 'Малика', phone: '+998901234567', role: 'WORKER' as const, workerId: 'w1', permissions: [] };

describe('/w/catalog with the real API shapes (the list has NO colours; the item has them)', () => {
  it('opens an item, loads its colours, orders 18 m', async () => {
    signIn(WORKER);
    const fetchMock = mockFetch({
      '/auth/me': WORKER,
      '/work/requests': { id: 'r1' },
      '/catalog/c1': { id: 'c1', name: 'Kokil lenta', description: 'Лента с бисером', availability: 'AVAILABLE', isNew: true, media: [], variants: [{ id: 'v1', label: null, color: { id: 'k1', name: 'Бордовый', hex: '#a3324f' } }] },
      '/catalog': { items: [{ id: 'c1', name: 'Kokil lenta', isNew: true, availability: 'AVAILABLE', coverPhoto: null, colors: [{ id: 'k1', name: 'Бордовый' }] }] },
    });
    renderWithProviders(<WorkerCatalog />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /Kokil lenta/ }));
    expect(await screen.findByText('Лента с бисером')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: /18 м/ }));
    await user.click(screen.getByRole('button', { name: 'Заказать эту работу' }));
    await waitFor(() => {
      const post = fetchMock.mock.calls.find(([u, init]) => String(u).includes('/work/requests') && init?.method === 'POST');
      expect(JSON.parse(String(post![1]!.body))).toEqual({ productVariantId: 'v1', kitCount: 2 });
    });
  });
});
