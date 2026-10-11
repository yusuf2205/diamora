import { ChatService } from '../src/chat/chat.service';
import { fetchLinkPreview } from '../src/chat/link-preview';
import { approveAndLoginWorker, createTestApp, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

describe('chat like Telegram, and more: polls, location, contact, cards, «Избранное», «позже», «без звука» (owner, 2026-10-11)', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  async function pair() {
    const a = await staffActor(t, 'ADMIN');
    const b = await staffActor(t, 'MANAGER');
    const room = (await a.api.post('/v1/chat/direct', { userId: b.user.id }).expect(200)).body;
    return { a, b, room };
  }

  it('a poll: options, one answer (changeable, takeable back), counts for everyone, who answered for the author', async () => {
    const { a, b, room } = await pair();
    const p = (await a.api.post(`/v1/chat/rooms/${room.id}/poll`, { question: 'Кто сможет взять работу в субботу?', options: ['Я', 'Не смогу'] }).expect(201)).body;
    expect(p.kind).toBe('POLL');
    expect(p.poll).toMatchObject({ question: 'Кто сможет взять работу в субботу?', voters: 0, multiple: false });

    await b.api.post(`/v1/chat/messages/${p.id}/vote`, { options: [0, 1] }).expect(400); // one answer only
    const v = (await b.api.post(`/v1/chat/messages/${p.id}/vote`, { options: [0] }).expect(200)).body;
    expect(v.poll.options[0]).toMatchObject({ count: 1, mine: true });
    expect(v.poll.voters).toBe(1);
    const seenByA = (await a.api.get(`/v1/chat/rooms/${room.id}/messages`).expect(200)).body.items[0];
    expect(seenByA.poll.options[0]).toMatchObject({ count: 1, mine: false });
    const who = (await a.api.get(`/v1/chat/messages/${p.id}/voters`).expect(200)).body;
    expect(who.options[0].people[0].id).toBe(b.user.id);
    expect((await b.api.post(`/v1/chat/messages/${p.id}/vote`, { options: [] }).expect(200)).body.poll.voters).toBe(0); // taken back
  });

  it('location, contact and a work card arrive as their own messages; the card only from staff', async () => {
    const { a, b, room } = await pair();
    const loc = (await a.api.post(`/v1/chat/rooms/${room.id}/location`, { latitude: 41.31, longitude: 69.28, label: 'Склад' }).expect(201)).body;
    expect(loc).toMatchObject({ kind: 'LOCATION', data: { latitude: 41.31, longitude: 69.28, label: 'Склад' } });
    const c = (await b.api.post(`/v1/chat/rooms/${room.id}/contact`, { name: 'Поставщик ленты', phone: '+998901112233' }).expect(201)).body;
    expect(c).toMatchObject({ kind: 'CONTACT', data: { name: 'Поставщик ленты' } });

    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const w = await approveAndLoginWorker(t, admin.api, reg.phone);
    const card = (await a.api.post(`/v1/chat/rooms/${room.id}/card`, { type: 'worker', id: w.workerId }).expect(201)).body;
    expect(card).toMatchObject({ kind: 'CARD', data: { type: 'worker', link: `/admin/workers/${w.workerId}` } });
    const rooms = (await b.api.get('/v1/chat/rooms').expect(200)).body.items;
    expect(rooms.find((r: { id: string }) => r.id === room.id).lastMessage.kind).toBe('CARD');
  });

  it('«Избранное»: my own chat, the same one every time, only mine', async () => {
    const { a, b } = await pair();
    const s1 = (await a.api.post('/v1/chat/saved').expect(200)).body;
    const s2 = (await a.api.post('/v1/chat/saved').expect(200)).body;
    expect(s1.id).toBe(s2.id);
    expect(s1).toMatchObject({ kind: 'SAVED', title: 'Избранное' });
    await a.api.post(`/v1/chat/rooms/${s1.id}/messages`, { text: 'не забыть ленту' }).expect(201);
    await b.api.get(`/v1/chat/rooms/${s1.id}/messages`).expect(404);
  });

  it('«Отправить позже»: kept until its time, then sent once as its author; can be cancelled', async () => {
    const { a, room } = await pair();
    const later = (await a.api.post(`/v1/chat/rooms/${room.id}/scheduled`, { text: 'Завтра заберу работу', sendAt: new Date(Date.now() + 3_600_000).toISOString() }).expect(201)).body;
    const cancelMe = (await a.api.post(`/v1/chat/rooms/${room.id}/scheduled`, { text: 'отменю', sendAt: new Date(Date.now() + 3_600_000).toISOString() }).expect(201)).body;
    expect((await a.api.get(`/v1/chat/rooms/${room.id}/scheduled`).expect(200)).body.items).toHaveLength(2);
    await a.api.delete(`/v1/chat/scheduled/${cancelMe.id}`).expect(200);

    const chat = t.app.get(ChatService);
    await chat.sendDue(new Date(Date.now() + 3_700_000));
    await chat.sendDue(new Date(Date.now() + 3_700_000)); // twice: still once
    const msgs = (await a.api.get(`/v1/chat/rooms/${room.id}/messages`).expect(200)).body.items.filter((m: { text: string }) => m.text === 'Завтра заберу работу');
    expect(msgs).toHaveLength(1);
    expect(msgs[0].sender.id).toBe(a.user.id);
    expect((await a.api.get(`/v1/chat/rooms/${room.id}/scheduled`).expect(200)).body.items).toHaveLength(0);
    expect(later.id).toBeTruthy();
  });

  it('«без звука» is kept on the message; a link to our own network never gets fetched', async () => {
    const { a, room } = await pair();
    const m = (await a.api.post(`/v1/chat/rooms/${room.id}/messages`, { text: 'тихо', silent: true }).expect(201)).body;
    expect((await t.prisma.chatMessage.findUniqueOrThrow({ where: { id: m.id } })).silent).toBe(true);
    expect(await fetchLinkPreview('http://127.0.0.1:3000/')).toBeNull();
    expect(await fetchLinkPreview('http://192.168.1.1/admin')).toBeNull();
    expect(await fetchLinkPreview('file:///etc/passwd')).toBeNull();
  });
});
