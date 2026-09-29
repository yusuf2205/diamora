import { COMPANY_ROOM_ID } from '../src/chat/chat.service';
import { createTestApp, jpeg, staffActor, TestApp } from './support/app';

/** Chat, stage 2: replies, edits, reactions, forwards, a pinned message, pinned / muted chats, search, typing. */
describe('chat v2', () => {
  let t: TestApp;
  beforeAll(async () => { t = await createTestApp(); });
  afterAll(async () => { await t.close(); });

  const pair = async () => {
    const a = await staffActor(t, 'ADMIN');
    const b = await staffActor(t, 'MANAGER');
    const room = (await a.api.post('/v1/chat/direct', { userId: b.user.id }).expect(200)).body;
    return { a, b, room };
  };

  it('reply, edit (own only, marked «изменено»), one reaction per person (again = take back)', async () => {
    const { a, b, room } = await pair();
    const q = (await a.api.post(`/v1/chat/rooms/${room.id}/messages`, { text: 'Сколько метров осталось?' }).expect(201)).body;
    const ans = (await b.api.post(`/v1/chat/rooms/${room.id}/messages`, { text: '12 метров', replyToId: q.id }).expect(201)).body;
    expect(ans.replyTo).toMatchObject({ id: q.id, sender: a.user.fullName, preview: 'Сколько метров осталось?' });

    await b.api.patch(`/v1/chat/messages/${q.id}`, { text: 'чужое' }).expect(403);
    const edited = (await b.api.patch(`/v1/chat/messages/${ans.id}`, { text: '15 метров' }).expect(200)).body;
    expect(edited).toMatchObject({ text: '15 метров' });
    expect(edited.editedAt).toBeTruthy();

    t.events.length = 0;
    const r1 = (await a.api.post(`/v1/chat/messages/${ans.id}/reactions`, { emoji: '👍' }).expect(200)).body;
    expect(r1.reactions).toEqual([{ emoji: '👍', count: 1, mine: true }]);
    expect(t.events.some((e) => e.type === 'chat.message_updated')).toBe(true);
    await b.api.post(`/v1/chat/messages/${ans.id}/reactions`, { emoji: '👍' }).expect(200);
    const r3 = (await a.api.post(`/v1/chat/messages/${ans.id}/reactions`, { emoji: '❤️' }).expect(200)).body; // replaces mine
    expect(r3.reactions).toEqual(expect.arrayContaining([{ emoji: '👍', count: 1, mine: false }, { emoji: '❤️', count: 1, mine: true }]));
    const r4 = (await a.api.post(`/v1/chat/messages/${ans.id}/reactions`, { emoji: '❤️' }).expect(200)).body; // again = take back
    expect(r4.reactions).toEqual([{ emoji: '👍', count: 1, mine: false }]);
    await a.api.post(`/v1/chat/messages/${ans.id}/reactions`, { emoji: '<script>' }).expect(400); // only the offered set
  });

  it('forward: into a chat I am in (the file is shared), «Переслано от …»; never into a chat I am not in', async () => {
    const { a, b, room } = await pair();
    const photo = (await b.api.upload(`/v1/chat/rooms/${room.id}/files`, await jpeg(), 'p.jpg', { kind: 'IMAGE' }).expect(201)).body;
    const fwd = (await a.api.post(`/v1/chat/messages/${photo.id}/forward`, { roomIds: [COMPANY_ROOM_ID] }).expect(200)).body.items[0];
    expect(fwd).toMatchObject({ kind: 'IMAGE', roomId: COMPANY_ROOM_ID, forwardedFrom: b.user.fullName });
    expect(fwd.file.url).toBeTruthy();
    const stranger = await staffActor(t, 'MANAGER');
    const other = (await stranger.api.post('/v1/chat/groups', { title: 'Закрытая', memberIds: [(await staffActor(t, 'ADMIN')).user.id] }).expect(201)).body;
    await a.api.post(`/v1/chat/messages/${photo.id}/forward`, { roomIds: [other.id] }).expect(404);
    await stranger.api.post(`/v1/chat/messages/${photo.id}/forward`, { roomIds: [other.id] }).expect(404); // cannot read the original
  });

  it('pinned message (anyone in a direct chat, only admins in the company chat); my pinned and muted chats', async () => {
    const { a, b, room } = await pair();
    const m = (await b.api.post(`/v1/chat/rooms/${room.id}/messages`, { text: 'Адрес: Чиланзар 5' }).expect(201)).body;
    const pinned = (await b.api.post(`/v1/chat/rooms/${room.id}/pin`, { messageId: m.id }).expect(200)).body;
    expect(pinned.pinnedMessage).toMatchObject({ id: m.id, text: 'Адрес: Чиланзар 5' });
    expect((await a.api.get(`/v1/chat/rooms/${room.id}`).expect(200)).body.pinnedMessage.id).toBe(m.id);

    const c = (await b.api.post(`/v1/chat/rooms/${COMPANY_ROOM_ID}/messages`, { text: 'Всем привет' }).expect(201)).body;
    await b.api.post(`/v1/chat/rooms/${COMPANY_ROOM_ID}/pin`, { messageId: c.id }).expect(403); // a manager
    await a.api.post(`/v1/chat/rooms/${COMPANY_ROOM_ID}/pin`, { messageId: c.id }).expect(200); // an admin

    await a.api.patch(`/v1/chat/rooms/${room.id}/me`, { pinned: true, muted: true }).expect(200);
    const list = (await a.api.get('/v1/chat/rooms').expect(200)).body.items;
    expect(list[0]).toMatchObject({ id: room.id, pinned: true, muted: true }); // my pinned chat is above the company chat
    expect(list[1].kind).toBe('COMPANY');
  });

  it('search: chats by name, people, messages in my chats only', async () => {
    const { a, b, room } = await pair();
    await b.api.post(`/v1/chat/rooms/${room.id}/messages`, { text: 'Кружево бежевое 40 метров' }).expect(201);
    const stranger = await staffActor(t, 'MANAGER');
    const g = (await stranger.api.post('/v1/chat/groups', { title: 'Секрет', memberIds: [(await staffActor(t, 'ADMIN')).user.id] }).expect(201)).body;
    await stranger.api.post(`/v1/chat/rooms/${g.id}/messages`, { text: 'Кружево бежевое тайное' }).expect(201);

    const res = (await a.api.get('/v1/chat/search?q=кружево').expect(200)).body;
    expect(res.messages.map((m: { text: string }) => m.text)).toEqual(['Кружево бежевое 40 метров']); // not the group I am not in
    expect(res.messages[0].room.id).toBe(room.id);
    const byName = (await a.api.get(`/v1/chat/search?q=${encodeURIComponent(b.user.fullName.slice(0, 5))}`).expect(200)).body;
    expect(byName.people.some((p: { id: string }) => p.id === b.user.id)).toBe(true);
  });

  it('typing: relayed to the other members only, never to outsiders', async () => {
    const { a, b, room } = await pair();
    const svc = t.app.get((await import('../src/chat/chat.service')).ChatService);
    t.events.length = 0;
    const principal = { id: a.user.id, role: 'ADMIN', fullName: a.user.fullName, sessionId: 's', workerId: null, permissions: [] } as never;
    await svc.typing(principal, room.id, 'voice');
    const e = t.events.find((x) => x.type === 'chat.typing');
    expect(e!.data).toMatchObject({ roomId: room.id, userId: a.user.id, kind: 'voice', userIds: [b.user.id] });
    t.events.length = 0;
    const out = await staffActor(t, 'MANAGER');
    await svc.typing({ ...(principal as object), id: out.user.id } as never, room.id, 'text');
    expect(t.events.some((x) => x.type === 'chat.typing')).toBe(false);
  });
});
