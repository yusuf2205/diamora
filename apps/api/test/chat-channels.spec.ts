import { approveAndLoginWorker, createTestApp, jpeg, registerViaBot, staffActor, TestApp } from './support/app';

/** Chat, stage 4: announcement channels, group admins, «only admins write», photo / description, media & files, audit. */
describe('chat channels and group admins', () => {
  let t: TestApp;
  beforeAll(async () => { t = await createTestApp(); });
  afterAll(async () => { await t.close(); });

  it('a «workers» channel: an admin creates it, workers read it (joined automatically), only its admins post; managers never see it', async () => {
    const admin = await staffActor(t, 'ADMIN');
    const mgr = await staffActor(t, 'MANAGER');
    const reg = await registerViaBot(t, { name: 'Гульноза Рахимова' });
    const w = await approveAndLoginWorker(t, admin.api, reg.phone);

    await mgr.api.post('/v1/chat/channels', { title: 'Новости', audience: 'WORKERS' }).expect(403); // only administrators
    const ch = (await admin.api.post('/v1/chat/channels', { title: 'Объявления для мастериц', description: 'Важное от компании', audience: 'WORKERS' }).expect(201)).body;
    expect(ch).toMatchObject({ kind: 'CHANNEL', audience: 'WORKERS', canWrite: true, canManage: true, description: 'Важное от компании' });
    expect(await t.prisma.auditLog.count({ where: { action: 'chat.channel_created', entityId: ch.id } })).toBe(1);

    t.events.length = 0;
    await admin.api.post(`/v1/chat/rooms/${ch.id}/messages`, { text: 'С понедельника новые расценки' }).expect(201);
    const wUser = (await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.workerId } })).userId!;
    const ev = t.events.find((e) => e.type === 'chat.message');
    expect((ev!.data as { userIds: string[] }).userIds).toContain(wUser); // delivered to the audience, not just joined members
    expect((ev!.data as { userIds: string[] }).userIds).not.toContain(mgr.user.id);

    const wRooms = (await w.api.get('/v1/chat/rooms').expect(200)).body.items;
    expect(wRooms.find((r: { id: string }) => r.id === ch.id)).toMatchObject({ kind: 'CHANNEL', unread: 1 });
    const wView = (await w.api.get(`/v1/chat/rooms/${ch.id}`).expect(200)).body;
    expect(wView).toMatchObject({ canWrite: false, canManage: false });
    await w.api.post(`/v1/chat/rooms/${ch.id}/messages`, { text: 'можно вопрос?' }).expect(403);

    await mgr.api.get(`/v1/chat/rooms/${ch.id}`).expect(404); // not the audience
    expect((await mgr.api.get('/v1/chat/rooms').expect(200)).body.items.some((r: { id: string }) => r.id === ch.id)).toBe(false);
    await w.api.post(`/v1/chat/rooms/${ch.id}/leave`).expect(400); // an audience channel is muted, not left
  });

  it('group admins: the owner makes an admin; admins manage members; «only admins write»; only the owner chooses admins', async () => {
    const owner = await staffActor(t, 'MANAGER');
    const a = await staffActor(t, 'MANAGER');
    const b = await staffActor(t, 'MANAGER');
    const c = await staffActor(t, 'MANAGER');
    const g = (await owner.api.post('/v1/chat/groups', { title: 'Бригада', memberIds: [a.user.id, b.user.id] }).expect(201)).body;
    await a.api.patch(`/v1/chat/rooms/${g.id}`, { addIds: [c.user.id] }).expect(403);
    await owner.api.patch(`/v1/chat/rooms/${g.id}`, { adminIds: [a.user.id] }).expect(200);
    await a.api.patch(`/v1/chat/rooms/${g.id}`, { addIds: [c.user.id], description: 'Юнусабад' }).expect(200); // an admin manages
    await a.api.patch(`/v1/chat/rooms/${g.id}`, { adminIds: [b.user.id] }).expect(403); // but only the owner chooses admins

    await owner.api.patch(`/v1/chat/rooms/${g.id}`, { onlyAdminsWrite: true }).expect(200);
    await b.api.post(`/v1/chat/rooms/${g.id}/messages`, { text: 'привет' }).expect(403);
    await a.api.post(`/v1/chat/rooms/${g.id}/messages`, { text: 'Завтра сбор в 9' }).expect(201);
    const view = (await b.api.get(`/v1/chat/rooms/${g.id}`).expect(200)).body;
    expect(view).toMatchObject({ canWrite: false, onlyAdminsWrite: true, description: 'Юнусабад' });
    expect(view.members.find((m: { id: string }) => m.id === a.user.id)).toMatchObject({ isAdmin: true });

    // a group admin may delete someone else's message there; it is audited (never its text)
    const m = (await owner.api.post(`/v1/chat/rooms/${g.id}/messages`, { text: 'лишнее' }).expect(201)).body;
    await a.api.delete(`/v1/chat/messages/${m.id}`).expect(200);
    const log = await t.prisma.auditLog.findFirst({ where: { action: 'chat.message_deleted', entityId: m.id } });
    expect(JSON.stringify(log?.after)).not.toContain('лишнее');
  });

  it('photo (a real image only) and «медиа / файлы / ссылки» of a chat', async () => {
    const owner = await staffActor(t, 'ADMIN');
    const a = await staffActor(t, 'MANAGER');
    const g = (await owner.api.post('/v1/chat/groups', { title: 'Фото', memberIds: [a.user.id] }).expect(201)).body;
    const withPhoto = (await owner.api.upload(`/v1/chat/rooms/${g.id}/photo`, await jpeg(), 'g.jpg').expect(201)).body;
    expect(withPhoto.photo.thumbUrl).toContain('/thumb');
    await owner.api.upload(`/v1/chat/rooms/${g.id}/photo`, Buffer.from('not an image'), 'x.jpg').expect(422);
    await a.api.upload(`/v1/chat/rooms/${g.id}/photo`, await jpeg(), 'g.jpg').expect(403);

    await owner.api.upload(`/v1/chat/rooms/${g.id}/files`, await jpeg(), 'p.jpg', { kind: 'IMAGE' }).expect(201);
    await owner.api.upload(`/v1/chat/rooms/${g.id}/files`, Buffer.from('%PDF-1.4 test'), 'Отчёт.pdf', {}).expect(201);
    await a.api.post(`/v1/chat/rooms/${g.id}/messages`, { text: 'Каталог тут: https://diamoraa.uz/w/catalog' }).expect(201);
    const kinds = async (k: string) => (await a.api.get(`/v1/chat/rooms/${g.id}/media?kind=${k}`).expect(200)).body.items.map((m: { kind: string; text: string | null }) => m.kind + (m.text ? `:${m.text}` : ''));
    expect(await kinds('media')).toEqual(['IMAGE']);
    expect(await kinds('files')).toEqual(['FILE']);
    expect(await kinds('links')).toEqual(['TEXT:Каталог тут: https://diamoraa.uz/w/catalog']);
  });
});
