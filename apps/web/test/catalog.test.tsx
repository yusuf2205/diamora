import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import CatalogPage from '@/app/(app)/catalog/page';
import { mockFetch, renderWithProviders, signIn } from './helpers';

const ME = { id: 'a1', fullName: 'Admin', phone: '+998901112233', role: 'ADMIN' as const, workerId: null, permissions: ['CATALOG_VIEW', 'CATALOG_MANAGE'] };

describe('catalog page (M2 §21-22): "Наши работы" management, no price field anywhere', () => {
  it('lists items with their status and lets ADMIN publish one', async () => {
    signIn(ME);
    const fetchMock = mockFetch({
      '/auth/me': ME,
      '/admin/catalog': {
        items: [{ id: 'c1', code: 'PRD-0001', name: 'Комплект «Роза»', description: null, status: 'DRAFT', availability: 'AVAILABLE', isNew: false, sortOrder: 0, media: [], variants: [] }],
        nextCursor: null,
      },
    });
    renderWithProviders(<CatalogPage />);

    expect(await screen.findByText('Комплект «Роза»')).toBeInTheDocument();
    expect(screen.getByText('Черновик')).toBeInTheDocument();
    expect(screen.queryByText(/сум/)).not.toBeInTheDocument(); // never a price, anywhere on this page

    await userEvent.click(screen.getByRole('button', { name: 'Опубликовать' }));
    await waitFor(() => expect(fetchMock.mock.calls.some(([u]) => String(u).includes('/admin/catalog/c1/publish'))).toBe(true));
  });

  it('an empty catalog shows an honest empty state, not a broken grid', async () => {
    signIn(ME);
    mockFetch({ '/auth/me': ME, '/admin/catalog': { items: [], nextCursor: null } });
    renderWithProviders(<CatalogPage />);
    expect(await screen.findByText('Пока ничего нет')).toBeInTheDocument();
  });
});
