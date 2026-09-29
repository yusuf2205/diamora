import { fireEvent, screen, waitFor } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { render } from '@testing-library/react';
import { ChatApp, chatKindForFile, chatPreview, MediaViewer, RichText, type ChatMessage } from '@/components/chat';
import { albumsOf, barsOf, toBars, VoicePlayer } from '@/components/chat-extras';
import { HeaderBadges } from '@/components/header-badges';
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

  it('worker web (single pane): the list only, no «Выберите чат слева» beside it', async () => {
    search = new URLSearchParams();
    signIn({ ...ME, role: 'WORKER' as never, workerId: 'w1' });
    mockFetch({ '/auth/me': ME, '/chat/rooms': { items: [{ id: 'c', kind: 'COMPANY', title: null, peer: null, memberCount: 3, isOwner: false, unread: 0, lastMessage: null, lastMessageAt: '2026-09-29T08:00:00Z' }] } });
    const { container } = renderWithProviders(<ChatApp single />);
    expect(await screen.findByText('Общий чат')).toBeInTheDocument();
    expect(screen.getByText('Выберите чат слева').parentElement!.className).toMatch(/(^| )hidden( |$)/);
    expect(container.innerHTML).not.toContain('md:flex');
  });

  it('stage 2: a reply quote, «изменено», reactions (click = toggle), the pinned message on top', async () => {
    search = new URLSearchParams('room=r1');
    signIn(ME);
    const answer = { ...msg('0002', '12 метров'), replyTo: { id: '0001', sender: 'Юсуф', preview: 'Сколько осталось?', deleted: false }, editedAt: new Date().toISOString(), reactions: [{ emoji: '👍', count: 2, mine: false }] };
    const fetch = mockFetch({
      '/auth/me': ME,
      '/chat/messages/0002/reactions': { ...answer, reactions: [{ emoji: '👍', count: 3, mine: true }] },
      '/chat/rooms/r1/messages': { items: [answer], hasMore: false },
      '/chat/rooms/r1/read': { ok: true },
      '/chat/rooms/r1': { id: 'r1', kind: 'DIRECT', title: 'Нигора Азимова', isOwner: false, canManage: false, canPin: true, memberCount: 2, peer: { id: 'u2', fullName: 'Нигора Азимова', role: 'WORKER', online: false, lastSeenAt: new Date().toISOString() }, members: [], pinnedMessage: msg('p1', 'Адрес: Чиланзар 5') },
      '/chat/rooms': { items: [] },
      '/chat/unread': { count: 0 },
    });
    renderWithProviders(<ChatApp />);
    expect(await screen.findByText('Сколько осталось?')).toBeInTheDocument();
    expect(screen.getByText('изменено')).toBeInTheDocument();
    expect(screen.getByText('Закреплённое сообщение')).toBeInTheDocument();
    expect(screen.getByText('Адрес: Чиланзар 5')).toBeInTheDocument();
    expect(screen.getByText(/был\(а\) в сети/)).toBeInTheDocument();
    fireEvent.click(screen.getByText('👍 2'));
    await waitFor(() => expect(fetch.mock.calls.some(([u, init]) => String(u).endsWith('/chat/messages/0002/reactions') && init?.method === 'POST')).toBe(true));
  });

  it('links open in a new tab without a referrer; @mentions stand out; HTML stays text', () => {
    const { container } = render(<RichText text={'Смотри https://diamoraa.uz/w и @Нигора <img src=x onerror=alert(1)>'} />);
    const a = container.querySelector('a')!;
    expect(a.getAttribute('href')).toBe('https://diamoraa.uz/w');
    expect(a.getAttribute('rel')).toContain('noreferrer');
    expect(container.querySelector('b')!.textContent).toBe('@Нигора');
    expect(container.querySelector('img')).toBeNull();
  });

  it('a channel for a reader: no input, «публикуют только его администраторы»; subscribers count', async () => {
    search = new URLSearchParams('room=ch');
    signIn(ME);
    mockFetch({
      '/auth/me': ME,
      '/chat/rooms/ch/messages': { items: [msg('0001', 'С понедельника новые расценки', { id: 'a1', fullName: 'Админ', role: 'ADMIN' })], hasMore: false },
      '/chat/rooms/ch/read': { ok: true },
      '/chat/rooms/ch': { id: 'ch', kind: 'CHANNEL', title: 'Объявления', isOwner: false, canManage: false, canWrite: false, memberCount: 40, audience: 'WORKERS', peer: null, members: [] },
      '/chat/rooms': { items: [] },
      '/chat/unread': { count: 0 },
    });
    renderWithProviders(<ChatApp />);
    expect(await screen.findByText('С понедельника новые расценки')).toBeInTheDocument();
    expect(screen.getByText('Это канал: публикуют только его администраторы')).toBeInTheDocument();
    expect(screen.queryByLabelText('Сообщение')).toBeNull();
    expect(screen.getByText('Канал · подписчиков: 40')).toBeInTheDocument();
  });

  it('the viewer: a photo and a video side by side, arrows move between them, Esc closes; a video streams with its preview', () => {
    const photo = { ...msg('p1', 'образец'), kind: 'IMAGE' as const, file: { url: 'https://x/p', thumbUrl: 'https://x/pt', name: null, size: 1, mimeType: 'image/jpeg', durationMs: null, width: 800, height: 600 } };
    const video = { ...msg('v1', ''), kind: 'VIDEO' as const, file: { url: 'https://x/v', thumbUrl: 'https://x/vt', name: 'v.mp4', size: 12_000_000, mimeType: 'video/mp4', durationMs: 34_000, width: 1080, height: 1920 } };
    const onClose = vi.fn();
    const { container } = render(<MediaViewer items={[photo, video]} start={photo} onClose={onClose} />);
    expect(screen.getByText('1 / 2')).toBeInTheDocument();
    fireEvent.keyDown(document, { key: 'ArrowRight' });
    expect(screen.getByText('2 / 2')).toBeInTheDocument();
    const v = container.querySelector('video')!;
    expect(v.getAttribute('src')).toBe('https://x/v'); // played straight from the server, no full download first
    expect(v.getAttribute('poster')).toBe('https://x/vt');
    fireEvent.keyDown(document, { key: 'Escape' });
    expect(onClose).toHaveBeenCalled();
  });

  it('right click on a message: reactions on top, Ответить / Копировать / Переслать / Выделить; «прочитано в …»', async () => {
    search = new URLSearchParams('room=r1');
    signIn(ME);
    const mine = { ...msg('0002', 'Мой ответ', { id: 'me', fullName: 'Юсуф Адилов', role: 'SUPER_ADMIN' }) };
    mockFetch({
      '/auth/me': ME,
      '/chat/messages/0002/reads': { items: [{ id: 'u2', fullName: 'Нигора Азимова', role: 'WORKER', readAt: '2026-09-30T09:05:00Z' }] },
      '/chat/rooms/r1/messages': { items: [mine], hasMore: false },
      '/chat/rooms/r1/read': { ok: true },
      '/chat/rooms/r1': { id: 'r1', kind: 'DIRECT', title: 'Нигора Азимова', isOwner: false, canManage: false, canPin: true, canProtect: true, memberCount: 2, peer: { id: 'u2', fullName: 'Нигора Азимова', role: 'WORKER', online: true }, members: [] },
      '/chat/rooms': { items: [] },
      '/chat/unread': { count: 0 },
    });
    renderWithProviders(<ChatApp />);
    fireEvent.contextMenu(await screen.findByText('Мой ответ'), { clientX: 100, clientY: 100 });
    expect(screen.getByRole('menu')).toBeInTheDocument();
    expect(screen.getByLabelText('Реакция 👍')).toBeInTheDocument();
    for (const t of ['Ответить', 'Изменить', 'Закрепить', 'Копировать текст', 'Переслать', 'Удалить', 'Выделить']) expect(screen.getByText(t)).toBeInTheDocument();
    expect(await screen.findByText(/прочитано в \d\d:\d\d/)).toBeInTheDocument();
    fireEvent.click(screen.getByText('Выделить'));
    expect(screen.getByText('Выбрано: 1')).toBeInTheDocument();
  });

  it('albums: photos of one sender sent together form one grid; a caption or another sender breaks it', () => {
    const img = (id: string, sender: string, t: number, text: string | null = null) => ({ ...msg(id, text ?? '', { id: sender, fullName: sender, role: 'ADMIN' }), text, kind: 'IMAGE' as const, createdAt: new Date(1_700_000_000_000 + t).toISOString(), file: { url: 'u', thumbUrl: 't', name: null, size: 1, mimeType: 'image/jpeg', durationMs: null, width: 1, height: 1 } });
    const out = albumsOf([img('1', 'a', 0), img('2', 'a', 1000), img('3', 'a', 2000), img('4', 'b', 3000), img('5', 'b', 4000, 'подпись')]);
    expect(out.map((x) => (Array.isArray(x) ? x.map((y) => y.id).join('+') : x.id))).toEqual(['1+2+3', '4', '5']);
  });

  it('voice: a waveform of 48 bars (0-31) from what was recorded; a stable pattern when there is none', () => {
    expect(toBars([0, 0.5, 1, 0.25], 4)).toEqual([1, 16, 31, 8]);
    expect(barsOf('1,2,3', 'x', 5)).toEqual([1, 2, 3, 1, 1]);
    expect(barsOf(null, 'abc')).toEqual(barsOf(null, 'abc'));
    const { container } = render(<VoicePlayer id="v" url="https://x/v.m4a" waveform={'5,10,31'} durationMs={2000} size={9011} mine />);
    expect(container.querySelectorAll('[role=slider] span').length).toBe(48);
    expect(screen.getByText('00:02, 8.8 KB')).toBeInTheDocument();
  });

  it('header: a big 🔔 with the unread count and the list, a big 💬 with the chat count', async () => {
    signIn(ME);
    mockFetch({ '/auth/me': ME, '/me/notifications': { unread: 3, items: [{ id: 'n1', title: 'Новая работа', body: 'Лента', link: null, read: false, createdAt: new Date().toISOString() }] } });
    renderWithProviders(<HeaderBadges chatUnread={5} />);
    expect(await screen.findByLabelText('Уведомления: непрочитанных 3')).toBeInTheDocument();
    expect(screen.getByLabelText('Чат: непрочитанных 5')).toBeInTheDocument();
    fireEvent.click(screen.getByLabelText('Уведомления: непрочитанных 3'));
    expect(screen.getByText('Новая работа')).toBeInTheDocument();
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
