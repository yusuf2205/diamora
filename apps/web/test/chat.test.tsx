import { fireEvent, screen, waitFor } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { ChatApp, chatKindForFile, chatPreview, type ChatMessage } from '@/components/chat';
import { mockFetch, renderWithProviders, signIn } from './helpers';

let search = new URLSearchParams();
const push = vi.fn();
vi.mock('next/navigation', () => ({ useRouter: () => ({ push, replace: vi.fn() }), usePathname: () => '/chat', useSearchParams: () => search, useParams: () => ({}) }));

const ME = { id: 'me', fullName: 'Юсуф Адилов', phone: '+998901112233', role: 'SUPER_ADMIN' as const, workerId: null, permissions: [] };
const msg = (id: string, text: string, sender = { id: 'u2', fullName: 'Нигора Азимова', role: 'WORKER' }): ChatMessage =>
  ({ id, roomId: 'r1', kind: 'TEXT', text, sender, file: null, deleted: false, createdAt: new Date().toISOString(), clientId: null });

describe('«Чат» on the web (panel and worker web share it)', () => {
  it('the list: company chat first, a direct chat with its last message and unread count; a click opens it', async () => {
    search = new URLSearchParams();
    signIn(ME);
    mockFetch({
      '/auth/me': ME,
      '/chat/rooms': { items: [
        { id: 'c', kind: 'COMPANY', title: null, peer: null, memberCount: 12, isOwner: false, unread: 0, lastMessage: null, lastMessageAt: '2026-09-29T08:00:00Z' },
        { id: 'r1', kind: 'DIRECT', title: 'Нигора Азимова', peer: { id: 'u2', fullName: 'Нигора Азимова', role: 'WORKER', online: true }, memberCount: 2, isOwner: false, unread: 2, lastMessage: msg('m1', 'Работа готова'), lastMessageAt: '2026-09-29T09:00:00Z' },
      ] },
    });
    renderWithProviders(<ChatApp />);
    expect(await screen.findByText('Общий чат')).toBeInTheDocument();
    expect(screen.getByText('Все сотрудники и мастерицы')).toBeInTheDocument();
    expect(screen.getByText('Работа готова')).toBeInTheDocument();
    expect(screen.getByText('2')).toBeInTheDocument();
    fireEvent.click(screen.getByText('Нигора Азимова'));
    expect(push).toHaveBeenCalledWith('/chat?room=r1');
  });

  it('a conversation: messages oldest→newest, ✓✓ when read; Enter sends the text', async () => {
    search = new URLSearchParams('room=r1');
    signIn(ME);
    const fetch = mockFetch({
      '/auth/me': ME,
      '/chat/rooms/r1/messages': { items: [msg('0002', 'Мой ответ', { id: 'me', fullName: 'Юсуф Адилов', role: 'SUPER_ADMIN' }), msg('0001', 'Работа готова')], hasMore: false },
      '/chat/rooms/r1/read': { ok: true },
      '/chat/rooms/r1': { id: 'r1', kind: 'DIRECT', title: 'Нигора Азимова', isOwner: false, canManage: false, memberCount: 2, peer: { id: 'u2', fullName: 'Нигора Азимова', role: 'WORKER', online: true, lastReadAt: new Date(Date.now() + 60_000).toISOString() }, members: [] },
      '/chat/rooms': { items: [] },
      '/chat/unread': { count: 0 },
    });
    renderWithProviders(<ChatApp />);
    const first = await screen.findByText('Работа готова');
    const second = screen.getByText('Мой ответ');
    expect(first.compareDocumentPosition(second) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy(); // older above
    expect(screen.getByLabelText('Прочитано')).toBeInTheDocument();
    expect(screen.getByText('в сети')).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText('Сообщение'), { target: { value: 'Завтра в 10' } });
    fireEvent.keyDown(screen.getByLabelText('Сообщение'), { key: 'Enter' });
    await waitFor(() => {
      const call = fetch.mock.calls.find(([u, init]) => String(u).endsWith('/chat/rooms/r1/messages') && init?.method === 'POST');
      expect(call).toBeTruthy();
      expect(JSON.parse(String(call![1]!.body)).text).toBe('Завтра в 10');
    });
  });

  it('previews and file kinds', () => {
    expect(chatPreview({ ...msg('x', ''), kind: 'VOICE' })).toBe('🎤 Голосовое сообщение');
    expect(chatPreview({ ...msg('x', 'подпись'), kind: 'IMAGE' })).toBe('📷 Фото · подпись');
    expect(chatPreview({ ...msg('x', 'a'), deleted: true })).toBe('Сообщение удалено');
    expect(chatKindForFile({ name: 'a.jpg', type: 'image/jpeg' })).toBe('IMAGE');
    expect(chatKindForFile({ name: 'a.heic', type: 'image/heic' })).toBe('FILE');
    expect(chatKindForFile({ name: 'v.mp4', type: 'video/mp4' })).toBe('VIDEO');
    expect(chatKindForFile({ name: 'x.pdf', type: 'application/pdf' })).toBe('FILE');
  });
});
