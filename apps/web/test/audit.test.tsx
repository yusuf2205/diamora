import { fireEvent, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import AuditPage from '@/app/(app)/audit/page';
import { mockFetch, renderWithProviders, signIn } from './helpers';

vi.mock('next/navigation', () => ({ useRouter: () => ({ push: vi.fn() }), useParams: () => ({}) }));

const OWNER = { id: 'sa1', fullName: 'Owner', phone: '+998901112233', role: 'SUPER_ADMIN' as const, workerId: null, permissions: ['AUDIT_VIEW'] };

describe('«Журнал действий»: who by name, what by name, and exactly what changed', () => {
  it('a row names the person and the object; tapping it shows before → after in plain words', async () => {
    signIn(OWNER);
    mockFetch({
      '/auth/me': OWNER,
      '/audit': {
        items: [{
          id: 'l1', action: 'settings.company_contact', entity: 'CompanyContactSettings', entityId: null, actorId: 'sa1', actorRole: 'SUPER_ADMIN',
          actorName: 'Юсуф Адилов', targetName: null, before: { phone: null, telegramUsername: null }, after: { phone: '+998903489818', telegramUsername: 'yusmus9606' },
          ip: '84.54.1.2', device: 'Chrome', requestId: null, createdAt: '2026-09-24T17:45:00Z',
        }, {
          id: 'l2', action: 'user.role_change', entity: 'User', entityId: 'u2', actorId: 'sa1', actorRole: 'SUPER_ADMIN',
          actorName: 'Юсуф Адилов', targetName: 'Adilova Muslima', before: { role: 'MANAGER' }, after: { role: 'ADMIN' },
          requestId: null, createdAt: '2026-09-24T17:40:00Z',
        }],
        nextCursor: null,
      },
    });
    renderWithProviders(<AuditPage />);
    expect((await screen.findAllByText('Юсуф Адилов (Главный администратор)')).length).toBe(2);
    expect(screen.getByText('Adilova Muslima')).toBeInTheDocument();

    fireEvent.click(screen.getByText('Изменена роль'));
    expect(await screen.findByText('Менеджер')).toBeInTheDocument();
    expect(screen.getByText('Администратор')).toBeInTheDocument();
  });

  it('a contact change lists each field: phone and Telegram, before and after', async () => {
    signIn(OWNER);
    mockFetch({
      '/auth/me': OWNER,
      '/audit': { items: [{
        id: 'l1', action: 'settings.company_contact', entity: 'CompanyContactSettings', entityId: null, actorId: 'sa1', actorRole: 'SUPER_ADMIN',
        actorName: 'Юсуф Адилов', targetName: null, before: { phone: '+998900000000', telegramUsername: null }, after: { phone: '+998903489818', telegramUsername: 'yusmus9606' },
        requestId: null, createdAt: '2026-09-24T17:45:00Z',
      }], nextCursor: null },
    });
    renderWithProviders(<AuditPage />);
    fireEvent.click(await screen.findByText('Изменены контакты компании'));
    expect(await screen.findByText('+998900000000')).toBeInTheDocument();
    expect(screen.getByText('+998903489818')).toBeInTheDocument();
    expect(screen.getByText('yusmus9606')).toBeInTheDocument();
    expect(screen.getByText('Telegram')).toBeInTheDocument();
  });
});
