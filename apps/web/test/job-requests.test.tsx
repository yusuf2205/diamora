import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { JobRequestsCard } from '@/app/(app)/dashboard/job-requests';
import { mockFetch, renderWithProviders, signIn } from './helpers';

vi.mock('next/navigation', () => ({ useRouter: () => ({ push: vi.fn() }), useSearchParams: () => new URLSearchParams() }));

const ME = { id: 's1', fullName: 'Owner', phone: '+998901112233', role: 'SUPER_ADMIN' as const, workerId: null, permissions: ['ASSIGNMENT_CREATE', 'ASSIGNMENT_VIEW_ALL'] };
const request = {
  id: 'r1', status: 'PENDING', kitCount: 2, meters: 18, note: 'к пятнице', decisionNote: null, createdAt: '2026-09-28T09:00:00Z',
  worker: { id: 'w1', code: 'W-0001', fullName: 'Малика Каримова', phone: '+998901234567' },
  product: { id: 'p1', name: 'Oddiy tekis' }, variant: { id: 'v1', label: null }, color: { id: 'c1', name: 'Pushti', hex: '#f4a6c0' }, assignmentId: null,
};

describe('«Заявки на работу» on the staff overview', () => {
  it('shows who ordered what; «Отклонить» sends the reason', async () => {
    signIn(ME);
    const fetchMock = mockFetch({ '/auth/me': ME, '/admin/job-requests': { items: [request] } });
    renderWithProviders(<JobRequestsCard canCreate />);
    expect(await screen.findByText('Малика Каримова')).toBeInTheDocument();
    expect(screen.getByText(/Oddiy tekis · Pushti · 18 м/)).toBeInTheDocument();
    expect(screen.getByText('«к пятнице»')).toBeInTheDocument();
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Отклонить' }));
    await user.type(screen.getByLabelText('Причина'), 'нет бисера');
    await user.click(screen.getAllByRole('button', { name: 'Отклонить' }).at(-1)!);
    await waitFor(() => {
      const call = fetchMock.mock.calls.find(([u, init]) => String(u).includes('/admin/job-requests/r1/reject') && init?.method === 'POST');
      expect(JSON.parse(String(call![1]!.body))).toEqual({ note: 'нет бисера' });
    });
  });

  it('nothing when there are no requests; no buttons without ASSIGNMENT_CREATE', async () => {
    signIn(ME);
    mockFetch({ '/auth/me': ME, '/admin/job-requests': { items: [request] } });
    renderWithProviders(<JobRequestsCard canCreate={false} />);
    expect(await screen.findByText('Малика Каримова')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Подготовить работу' })).not.toBeInTheDocument();
  });
});
