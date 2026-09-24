import { fireEvent, screen, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import InventoryPage from '@/app/(app)/inventory/page';
import { ColorsCard } from '@/app/(app)/catalog/[id]/colors-card';
import type { CatalogItem } from '@/lib/types';
import { mockFetch, renderWithProviders, signIn } from './helpers';

vi.mock('next/navigation', () => ({ useRouter: () => ({ push: vi.fn() }), useParams: () => ({}) }));

const ADMIN = { id: 'a1', fullName: 'Owner', phone: '+998901112233', role: 'SUPER_ADMIN' as const, workerId: null, permissions: ['INVENTORY_VIEW', 'INVENTORY_MANAGE', 'CATALOG_MANAGE'] };
const tape = { id: 'm1', name: 'Лента атласная', unit: 'METER', balance: 12, minStock: 50, low: true, isActive: true };
const beads = { id: 'm2', name: 'Бусины 6 мм', unit: 'PCS', balance: 0, minStock: 100, low: true, isActive: true };
const bodies = (fetch: ReturnType<typeof mockFetch>, path: string) =>
  fetch.mock.calls.filter(([u, i]) => String(u).includes(path) && (i as RequestInit | undefined)?.method === 'POST').map(([, i]) => JSON.parse(String((i as RequestInit).body)));

describe('web «Склад»: stock at a glance, receipts and 9 m kits, all through the same API as the app', () => {
  beforeEach(() => signIn(ADMIN));

  it('shows balances with plain warnings; tapping a material records a receipt', async () => {
    const fetch = mockFetch({ '/auth/me': ADMIN, '/admin/stock/receipt': {}, '/admin/materials': { items: [tape, beads], nextCursor: null }, '/admin/kits': { items: [] } });
    renderWithProviders(<InventoryPage />);
    expect(await screen.findByText('Лента атласная')).toBeInTheDocument();
    expect(screen.getByText('Мало')).toBeInTheDocument();
    expect(screen.getByText('Закончился')).toBeInTheDocument();

    fireEvent.click(screen.getByText('Лента атласная'));
    fireEvent.change(await screen.findByLabelText('Пришло, м'), { target: { value: '100' } });
    fireEvent.click(screen.getByRole('button', { name: 'Добавить на склад' }));
    await waitFor(() => expect(bodies(fetch, '/admin/stock/receipt')).toEqual([{ materialId: 'm1', quantity: '100' }]));
  });

  it('a new 9 m kit sends exactly the chosen materials and quantities', async () => {
    const fetch = mockFetch({ '/auth/me': ADMIN, '/admin/materials': { items: [tape, beads], nextCursor: null }, '/admin/kits': { items: [] } });
    renderWithProviders(<InventoryPage />);
    await screen.findByText('Лента атласная');
    fireEvent.click(screen.getByRole('button', { name: 'Комплекты 9 м' }));
    expect(await screen.findByText('Комплектов пока нет')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: '+ Комплект' }));
    fireEvent.change(await screen.findByLabelText('Материал 1'), { target: { value: 'm1' } });
    fireEvent.change(screen.getByLabelText('Количество 1'), { target: { value: '9' } });
    fireEvent.click(screen.getByRole('button', { name: 'Сохранить комплект' }));
    await waitFor(() => expect(bodies(fetch, '/admin/kits')).toEqual([{ name: 'Комплект 9 м', ribbonMeters: 9, items: [{ materialId: 'm1', requiredQuantity: '9' }] }]));
  });
});

describe('catalog «Цвета»: a model without a colour cannot be issued, so adding one is one step', () => {
  beforeEach(() => signIn(ADMIN));
  const item = { id: 'p1', code: 'P-1', name: 'Oddiy tekis', description: null, status: 'PUBLISHED', availability: 'AVAILABLE', isNew: false, sortOrder: 0, media: [], variants: [] } as unknown as CatalogItem;

  it('warns when there is no colour and creates a new colour then attaches it', async () => {
    const fetch = mockFetch({ '/auth/me': ADMIN, '/admin/catalog/p1/variants': { ...item }, '/admin/colors': { id: 'c9', name: 'Розовое золото', hex: null, isActive: true } });
    renderWithProviders(<ColorsCard item={item} canManage />);
    expect(screen.getByText(/нельзя выдать мастерице/)).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText(/Новый цвет/), { target: { value: 'Розовое золото' } });
    fireEvent.click(screen.getByRole('button', { name: '+ Добавить цвет' }));
    await waitFor(() => expect(bodies(fetch, '/admin/catalog/p1/variants')).toEqual([{ colorId: 'c9' }]));
    expect(bodies(fetch, '/admin/colors')).toEqual([{ name: 'Розовое золото' }]);
  });
});
