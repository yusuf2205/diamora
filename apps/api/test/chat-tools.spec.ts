import { approveAndLoginWorker, createTestApp, jpeg, registerViaBot, staffActor, TestApp } from './support/app';

/** Telegram-like tools: profile (photo, «о себе», @username), clear / delete chat for me, protect content, export,
 *  «прочитано когда?», search in a chat, counts, voice waveform. */
describe('chat tools and profile', () => {
  let t: TestApp;
  beforeAll(async () => { t = await createTestApp(); });
  afterAll(async () => { await t.close(); });

  it('my profile: photo, «о себе», a unique @username; others see it on my card (the phone only for staff)', async () => {
    const a = await staffActor(t, 'ADMIN');
    const b = await staffActor(t, 'MANAGER');
    const me = (await a.api.upload('/v1/auth/me/avatar', await jpeg(), 'me.jpg').expect(201)).body;
    expect(me.avatar.thumbUrl).toContain('/thumb');
    const u1 = (await a.api.patch('/v1/auth/me', { bio: 'Спокойствие только в поклонении', username: '@Yusuf_Admin' }).expect(200)).body;
    expect(u1).toMatchObject({ bio: 'Спокойствие только в поклонении', username: 'yusuf_admin' });
    await b.api.patch('/v1/auth/me', { username: 'yusuf_admin' }).expect(409);
    await b.api.patch('/v1/auth/me', { username: 'a!' }).expect(400);

    const card = (await b.api.get(`/v1/chat/users/${a.user.id}`).expect(200)).body;
    expect(card).toMatchObject({ fullName: a.user.fullName, bio: 'Спокойствие только в поклонении', username: 'yusuf_admin', phone: a.user.phone });
    expect(card.avatar).toContain('/thumb');

    const reg = await registerViaBot(t, { name: 'Мохира Ахмедова' });
    const w = await approveAndLoginWorker(t, a.api, reg.phone);
    expect((await w.api.get(`/v1/chat/users/${a.user.id}`).expect(200)).body.phone).toBeNull(); // a worker never sees phones
    await w.api.get(`/v1/chat/users/${b.user.id}`).expect(404); // not her manager, no shared chat
  });

  it('clear history and delete a direct chat - for me only; it comes back with a new message', async () => {
    const a = await staffActor(t, 'ADMIN');
    const b = await staffActor(t, 'MANAGER');
    const room = (await a.api.post('/v1/chat/direct', { userId: b.user.id }).expect(200)).body;
    await b.api.post(`/v1/chat/rooms/${room.id}/messages`, { text: 'старое' }).expect(201);
    await a.api.post(`/v1/chat/rooms/${room.id}/clear`).expect(200);
    expect((await a.api.get(`/v1/chat/rooms/${room.id}/messages`).expect(200)).body.items).toEqual([]);
    expect((await b.api.get(`/v1/chat/rooms/${room.id}/messages`).expect(200)).body.items.length).toBe(1); // hers stays

    await a.api.delete(`/v1/chat/rooms/${room.id}`).expect(200);
    expect((await a.api.get('/v1/chat/rooms').expect(200)).body.items.some((r: { id: string }) => r.id === room.id)).toBe(false);
    await new Promise((r) => setTimeout(r, 5));
    await b.api.post(`/v1/chat/rooms/${room.id}/messages`, { text: 'новое' }).expect(201);
    const back = (await a.api.get('/v1/chat/rooms').expect(200)).body.items.find((r: { id: string }) => r.id === room.id);
    expect(back).toMatchObject({ unread: 1, lastMessage: { text: 'новое' } });
  });

  it('protect content: no forwarding, no export for members; «прочитано когда?»; search in a chat; counts; waveform', async () => {
    const owner = await staffActor(t, 'MANAGER');
    const m1 = await staffActor(t, 'MANAGER');
    const g = (await owner.api.post('/v1/chat/groups', { title: 'Закрытая', memberIds: [m1.user.id] }).expect(201)).body;
    const msg = (await owner.api.post(`/v1/chat/rooms/${g.id}/messages`, { text: 'Цена кружева 12 000' }).expect(201)).body;
    await m1.api.post(`/v1/chat/rooms/${g.id}/protect`, { on: true }).expect(403);
    expect((await owner.api.post(`/v1/chat/rooms/${g.id}/protect`, { on: true }).expect(200)).body.protectContent).toBe(true);
    const direct = (await m1.api.post('/v1/chat/direct', { userId: owner.user.id }).expect(200)).body;
    await m1.api.post(`/v1/chat/messages/${msg.id}/forward`, { roomIds: [direct.id] }).expect(403);
    await m1.api.get(`/v1/chat/rooms/${g.id}/export`).expect(403);
    const txt = await owner.api.get(`/v1/chat/rooms/${g.id}/export`).expect(200);
    expect(txt.text).toContain('Цена кружева 12 000');

    await m1.api.post(`/v1/chat/rooms/${g.id}/read`).expect(200);
    const reads = (await owner.api.get(`/v1/chat/messages/${msg.id}/reads`).expect(200)).body.items;
    expect(reads.map((r: { id: string }) => r.id)).toEqual([m1.user.id]);
    expect(reads[0].readAt).toBeTruthy();

    expect((await m1.api.get(`/v1/chat/rooms/${g.id}/search?q=кружев`).expect(200)).body.items.map((x: { id: string }) => x.id)).toEqual([msg.id]);

    const wave = '1,5,9,14,20,31,28,17,8,3';
    const m4a = Buffer.concat([Buffer.from([0, 0, 0, 0x20]), Buffer.from('ftypM4A '), Buffer.alloc(200, 1)]);
    const voice = (await owner.api.upload(`/v1/chat/rooms/${g.id}/files`, m4a, 'voice.m4a', { kind: 'VOICE', durationMs: '2000', waveform: wave }).expect(201)).body;
    expect(voice.waveform).toBe(wave);
    expect((await m1.api.get(`/v1/chat/rooms/${g.id}/counts`).expect(200)).body).toMatchObject({ voice: 1, photos: 0 });
  });
});
