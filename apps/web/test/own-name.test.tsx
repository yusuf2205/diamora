import { fireEvent, screen, waitFor } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import ProfilePage from '@/app/(app)/profile/page';
import WorkerProfile from '@/app/w/profile/page';
import { splitName } from '@/components/own-name-form';
import { mockFetch, renderWithProviders, signIn } from './helpers';

vi.mock('next/navigation', () => ({ useRouter: () => ({ push: vi.fn(), replace: vi.fn() }), useParams: () => ({}) }));

const ME = { id: 'm1', fullName: 'Дилноза Юсупова', phone: '+998901112233', role: 'MANAGER' as const, workerId: null, permissions: [] };

describe('«Имя и фамилия»: everyone changes their own name', () => {
  it('splits on the first space', () => {
    expect(splitName('Малика Каримова')).toEqual(['Малика', 'Каримова']);
    expect(splitName('Малика')).toEqual(['Малика', '']);
    expect(splitName(' Ана Мария Лопес ')).toEqual(['Ана', 'Мария Лопес']);
  });

  it('staff: the fields start with my name; save sends PATCH /auth/me with the new one', async () => {
    signIn(ME);
    const fetch = mockFetch({ '/auth/me': ME });
    renderWithProviders(<ProfilePage />);
    const last = await screen.findByLabelText('Фамилия');
    await waitFor(() => expect(last).toHaveValue('Юсупова'));
    expect(screen.getByLabelText('Имя')).toHaveValue('Дилноза');
    fireEvent.change(last, { target: { value: 'Каримова' } });
    fireEvent.click(screen.getByRole('button', { name: 'Сохранить' }));
    await waitFor(() => {
      const call = fetch.mock.calls.find(([, init]) => init?.method === 'PATCH');
      expect(call).toBeTruthy();
      expect(JSON.parse(String(call![1]!.body))).toEqual({ fullName: 'Дилноза Каримова' });
    });
  });

  it('worker (web): the same form on her profile', async () => {
    signIn({ ...ME, role: 'WORKER' as never, workerId: 'w1' });
    mockFetch({ '/auth/me': ME, '/workers/me': { fullName: 'Малика Каримова', phone: '+998901112233', code: 'W-0001' } });
    renderWithProviders(<WorkerProfile />);
    await waitFor(() => expect(screen.getByLabelText('Имя')).toHaveValue('Малика'));
    expect(screen.getByRole('button', { name: 'Сохранить' })).toBeDisabled(); // nothing changed yet
  });
});
