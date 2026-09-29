import { COMPANY_ROOM_ID } from '../src/chat/chat.service';
import { approveAndLoginWorker, createTestApp, jpeg, registerViaBot, staffActor, TestApp } from './support/app';

/** Chat, everyone with everyone: direct, groups, the company chat; text and files up to 50 MB; only members read a room. */
describe('chat', () => {
  let t: TestApp;
  beforeAll(async () => { t = await createTestApp(); });
  afterAll(async () => { await t.close(); });

  const worker = async (admin: Awaited<ReturnType<typeof staffActor>>, name: string) => {
    const reg = await registerViaBot(t, { name });
    return approveAndLoginWorker(t, admin.api, reg.phone);
  };

  it('direct chat: a worker writes to a manager; one room per pair; unread, read receipts, realtime to both', async () => {
    const admin = await staffActor(t, 'ADMIN', ['WORKER_ASSIGN_MANAGER']);
    const mgr = await staffActor(t, 'MANAGER');
    const w = await worker(admin, 'Нигора Азимова');
    const wUser = (await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.workerId } })).userId!;
    await admin.api.post('/v1/workers/manager-bulk', { managerId: mgr.user.id, workerIds: [w.workerId] }).expect(200); // her manager

    // contacts: everyone active, names and roles, never phones
    const contacts = (await w.api.get('/v1/chat/contacts').expect(200)).body.items;
    const m = contacts.find((c: { id: string }) => c.id === mgr.user.id);
    expect(m).toMatchObject({ fullName: mgr.user.fullName, role: 'MANAGER' });
    expect(m.phone).toBeUndefined();

    const room = (await w.api.post('/v1/chat/direct', { userId: mgr.user.id }).expect(200)).body;
    expect(room.kind).toBe('DIRECT');
    expect((await mgr.api.post('/v1/chat/direct', { userId: wUser }).expect(200)).body.id).toBe(room.id); // same pair, same room

    t.events.length = 0;
    const sent = (await w.api.post(`/v1/chat/rooms/${room.id}/messages`, { text: 'Здравствуйте! Работа готова', clientId: 'c-1' }).expect(201)).body;
    expect(sent).toMatchObject({ kind: 'TEXT', text: 'Здравствуйте! Работа готова', sender: { id: wUser } });
    // a retried send (bad connection) does not post it twice
    expect((await w.api.post(`/v1/chat/rooms/${room.id}/messages`, { text: 'Здравствуйте! Работа готова', clientId: 'c-1' }).expect(201)).body.id).toBe(sent.id);
    const ev = t.events.find((e) => e.type === 'chat.message');
    expect((ev!.data as { userIds: string[] }).userIds.sort()).toEqual([wUser, mgr.user.id].sort());

    expect((await mgr.api.get('/v1/chat/unread').expect(200)).body.count).toBe(1);
    const list = (await mgr.api.get('/v1/chat/rooms').expect(200)).body.items;
    expect(list[0].kind).toBe('COMPANY'); // the company chat is always first
    const d = list.find((r: { id: string }) => r.id === room.id);
    expect(d).toMatchObject({ title: 'Нигора Азимова', unread: 1, lastMessage: { text: 'Здравствуйте! Работа готова' } });

    await mgr.api.post(`/v1/chat/rooms/${room.id}/read`).expect(200);
    expect((await mgr.api.get('/v1/chat/unread').expect(200)).body.count).toBe(0);
    const mine = (await w.api.get(`/v1/chat/rooms/${room.id}`).expect(200)).body;
    expect(mine.peer.lastReadAt).toBeTruthy(); // «прочитано» for the sender

    const page = (await mgr.api.get(`/v1/chat/rooms/${room.id}/messages`).expect(200)).body;
    expect(page.items.map((x: { text: string }) => x.text)).toEqual(['Здравствуйте! Работа готова']);

    // a third person cannot read or write the room (404: rooms are not enumerable)
    const other = await staffActor(t, 'MANAGER');
    await other.api.get(`/v1/chat/rooms/${room.id}/messages`).expect(404);
    await other.api.post(`/v1/chat/rooms/${room.id}/messages`, { text: 'hi' }).expect(404);
  });

  it('who sees whom: a worker - administrators and HER manager only; a manager - staff and HIS workers; an admin - every worker', async () => {
    const owner = await staffActor(t, 'SUPER_ADMIN');
    const admin = await staffActor(t, 'ADMIN');
    const mine = await staffActor(t, 'MANAGER');
    const other = await staffActor(t, 'MANAGER');
    const w1 = await worker(admin, 'Малика Юсупова');
    const w2 = await worker(admin, 'Дилноза Каримова');
    await owner.api.post('/v1/workers/manager-bulk', { managerId: mine.user.id, workerIds: [w1.workerId] }).expect(200);
    await owner.api.post('/v1/workers/manager-bulk', { managerId: other.user.id, workerIds: [w2.workerId] }).expect(200);
    const u1 = (await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w1.workerId } })).userId!;
    const u2 = (await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w2.workerId } })).userId!;
    const ids = async (a: { api: { get: (u: string) => { expect: (s: number) => Promise<{ body: { items: { id: string }[] } }> } } }) =>
      (await a.api.get('/v1/chat/contacts').expect(200)).body.items.map((c) => c.id);

    const forW1 = await ids(w1);
    expect(forW1).toEqual(expect.arrayContaining([owner.user.id, admin.user.id, mine.user.id]));
    expect(forW1).not.toContain(other.user.id); // not her manager
    expect(forW1).not.toContain(u2); // never other workers
    await w1.api.post('/v1/chat/direct', { userId: u2 }).expect(403); // checked on the server, not just hidden
    await w1.api.post('/v1/chat/direct', { userId: other.user.id }).expect(403);
    await w1.api.post('/v1/chat/direct', { userId: mine.user.id }).expect(200);

    const forMine = await ids(mine);
    expect(forMine).toContain(u1);
    expect(forMine).not.toContain(u2);
    expect(forMine).toEqual(expect.arrayContaining([owner.user.id, admin.user.id, other.user.id])); // staff talk to each other
    await mine.api.post('/v1/chat/groups', { title: 'Чужие', memberIds: [u2] }).expect(403);

    expect(await ids(admin)).toEqual(expect.arrayContaining([u1, u2]));
    expect(await ids(owner)).toEqual(expect.arrayContaining([u1, u2]));
  });

  it('group: owner creates, adds and removes; members write; a non-owner cannot manage; leaving hands ownership on', async () => {
    const owner = await staffActor(t, 'MANAGER');
    const a = await staffActor(t, 'MANAGER');
    const b = await staffActor(t, 'ADMIN');
    const c = await staffActor(t, 'MANAGER');
    const g = (await owner.api.post('/v1/chat/groups', { title: 'Бригада Юнусабад', memberIds: [a.user.id] }).expect(201)).body;
    expect(g).toMatchObject({ kind: 'GROUP', title: 'Бригада Юнусабад', isOwner: true, canManage: true, memberCount: 2 });

    await a.api.patch(`/v1/chat/rooms/${g.id}`, { title: 'Моя группа' }).expect(403);
    await owner.api.patch(`/v1/chat/rooms/${g.id}`, { addIds: [c.user.id] }).expect(200);
    await c.api.post(`/v1/chat/rooms/${g.id}/messages`, { text: 'Привет всем' }).expect(201);
    await b.api.get(`/v1/chat/rooms/${g.id}`).expect(404); // not a member
    await owner.api.patch(`/v1/chat/rooms/${g.id}`, { removeIds: [c.user.id] }).expect(200);
    await c.api.get(`/v1/chat/rooms/${g.id}/messages`).expect(404);

    await owner.api.post(`/v1/chat/rooms/${g.id}/leave`).expect(200);
    expect((await a.api.get(`/v1/chat/rooms/${g.id}`).expect(200)).body).toMatchObject({ isOwner: true, memberCount: 1 });
  });

  it('company chat: everyone is in it; a new member starts with nothing unread; admins delete any message, others only their own', async () => {
    const admin = await staffActor(t, 'ADMIN');
    const w = await worker(admin, 'Шахло Каримова');
    const m1 = (await w.api.post(`/v1/chat/rooms/${COMPANY_ROOM_ID}/messages`, { text: 'Всем привет' }).expect(201)).body;
    const late = await staffActor(t, 'MANAGER');
    expect((await late.api.get('/v1/chat/unread').expect(200)).body.count).toBe(0);
    const page = (await late.api.get(`/v1/chat/rooms/${COMPANY_ROOM_ID}/messages`).expect(200)).body;
    expect(page.items.some((x: { id: string }) => x.id === m1.id)).toBe(true); // history is readable

    await late.api.delete(`/v1/chat/messages/${m1.id}`).expect(403);
    await admin.api.delete(`/v1/chat/messages/${m1.id}`).expect(200);
    const after = (await w.api.get(`/v1/chat/rooms/${COMPANY_ROOM_ID}/messages`).expect(200)).body.items.find((x: { id: string }) => x.id === m1.id);
    expect(after).toMatchObject({ deleted: true, text: null });
  });

  it('files: a photo (resized + thumbnail), a voice note, a document (always downloaded, never rendered)', async () => {
    const a = await staffActor(t, 'ADMIN');
    const b = await staffActor(t, 'MANAGER');
    const room = (await a.api.post('/v1/chat/direct', { userId: b.user.id }).expect(200)).body;

    const photo = (await a.api.upload(`/v1/chat/rooms/${room.id}/files`, await jpeg(), 'IMG_1.jpg', { kind: 'IMAGE', text: 'Вот образец' }).expect(201)).body;
    expect(photo).toMatchObject({ kind: 'IMAGE', text: 'Вот образец', file: { mimeType: 'image/jpeg', width: 64, height: 48 } });
    expect(photo.file.thumbUrl).toContain('/thumb');

    // m4a (AAC in an MP4 container) as the phone records it
    const m4a = Buffer.concat([Buffer.from([0, 0, 0, 0x20]), Buffer.from('ftypM4A '), Buffer.alloc(200, 1)]);
    const voice = (await a.api.upload(`/v1/chat/rooms/${room.id}/files`, m4a, 'voice.m4a', { kind: 'VOICE', durationMs: '4200' }).expect(201)).body;
    expect(voice).toMatchObject({ kind: 'VOICE', file: { mimeType: 'audio/mp4', durationMs: 4200 } });

    const html = Buffer.from('<html><script>alert(1)</script></html>');
    const doc = (await a.api.upload(`/v1/chat/rooms/${room.id}/files`, html, 'report.html', {}).expect(201)).body;
    expect(doc).toMatchObject({ kind: 'FILE', file: { name: 'report.html', mimeType: 'application/octet-stream' } });
    const path = new URL(doc.file.url).pathname + new URL(doc.file.url).search;
    const res = await b.api.get(path).expect(200);
    expect(res.headers['content-type']).toBe('application/octet-stream');
    expect(res.headers['content-disposition']).toMatch(/^attachment/);

    // a "photo" that is not an image is kept as a plain file, not rejected
    const fake = (await a.api.upload(`/v1/chat/rooms/${room.id}/files`, Buffer.from('not an image'), 'x.jpg', { kind: 'IMAGE' }).expect(201)).body;
    expect(fake.kind).toBe('FILE');
  });

  it('needs a signed-in user', async () => {
    const anon = (await import('supertest')).default(t.app.getHttpServer());
    expect((await anon.get('/v1/chat/rooms')).status).toBe(401);
  });
});
