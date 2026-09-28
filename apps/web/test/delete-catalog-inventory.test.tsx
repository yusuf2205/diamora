import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import CatalogPage from '@/app/(app)/catalog/page';
import InventoryPage from '@/app/(app)/inventory/page';
import { mockFetch, renderWithProviders, signIn } from './helpers';

vi.mock('next/navigation', () => ({ useParams: () => ({}), useRouter: () => ({ push: vi.fn() }), useSearchParams: () => new URLSearchParams(), usePathname: () => '/' }));

const OWNER = { id: 's1', fullName: 'Owner', phone: '+998901112233', role: 'SUPER_ADMIN' as const, workerId: null, permissions: ['CATALOG_VIEW', 'CATALOG_MANAGE', 'CATALOG_DELETE', 'INVENTORY_VIEW', 'INVENTORY_MANAGE', 'INVENTORY_DELETE'] };
const ADMIN = { ...OWNER, role: 'ADMIN' as const, permissions: ['CATALOG_VIEW', 'CATALOG_MANAGE', 'INVENTORY_VIEW', 'INVENTORY_MANAGE'] };
const item = { id: 'c1', code: 'PRD-0001', name: 'Kokil lenta', description: null, status: 'PUBLISHED', availability: 'AVAILABLE', isNew: true, sortOrder: 0, media: [], variants: [] };
const material = { id: 'm1', name: 'Атласная лента (тест)', unit: 'METER', balance: 155, minStock: 50, low: false, isActive: true };

const deleted = (fetchMock: ReturnType<typeof mockFetch>, path: string) =>
  fetchMock.mock.calls.some(([u, init]) => String(u).endsWith(path) && init?.method === 'DELETE');

describe('«Удалить» in the catalog and the warehouse (only with the permission the SUPER_ADMIN grants)', () => {
  it('catalog: «Удалить» -> a plain confirm -> DELETE; never before the confirm', async () => {
    signIn(OWNER);
    const fetchMock = mockFetch({ '/auth/me': OWNER, '/admin/catalog': { items: [item], nextCursor: null } });
    renderWithProviders(<CatalogPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Удалить Kokil lenta' }));
    expect(deleted(fetchMock, '/admin/catalog/c1')).toBe(false);
    expect(screen.getByText(/исчезнет из каталога у всех/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Удалить' }));
    await waitFor(() => expect(deleted(fetchMock, '/admin/catalog/c1')).toBe(true));
  });

  it('warehouse: a material is deleted with the write-off said up front; a kit too', async () => {
    signIn(OWNER);
    const fetchMock = mockFetch({
      '/auth/me': OWNER, '/admin/materials': { items: [material], nextCursor: null },
      '/admin/kits': { items: [{ id: 'k1', name: 'Комплект 9 м', ribbonMeters: 9, active: true, items: [] }] },
    });
    renderWithProviders(<InventoryPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Удалить Атласная лента (тест)' }));
    expect(screen.getByText(/Остаток 155 м будет списан/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Удалить' }));
    await waitFor(() => expect(deleted(fetchMock, '/admin/materials/m1')).toBe(true));

    await user.click(screen.getByRole('button', { name: 'Комплекты 9 м' }));
    await user.click(await screen.findByRole('button', { name: 'Удалить Комплект 9 м' }));
    await user.click(screen.getByRole('button', { name: 'Удалить' }));
    await waitFor(() => expect(deleted(fetchMock, '/admin/kits/k1')).toBe(true));
  });

  it('without the delete permission there is no «Удалить» anywhere', async () => {
    signIn(ADMIN);
    mockFetch({ '/auth/me': ADMIN, '/admin/catalog': { items: [item], nextCursor: null } });
    renderWithProviders(<CatalogPage />);
    await screen.findByText('Kokil lenta');
    expect(screen.queryByRole('button', { name: /Удалить/ })).not.toBeInTheDocument();
  });
});
