import { approveAndLoginWorker, createTestApp, registerViaBot, staffActor, TestApp } from './support/app';

/** «Мой профиль»: everyone changes their OWN first name and surname; a worker's card follows; audited. */
describe('own name', () => {
  let t: TestApp;
  beforeAll(async () => { t = await createTestApp(); });
  afterAll(async () => { await t.close(); });

  it('staff: PATCH /auth/me renames me (spaces tidied), /auth/me shows it, the journal records it', async () => {
    const m = await staffActor(t, 'MANAGER');
    const res = await m.api.patch('/v1/auth/me', { fullName: '  Дилноза   Юсупова ' }).expect(200);
    expect(res.body.fullName).toBe('Дилноза Юсупова');
    expect((await m.api.get('/v1/auth/me').expect(200)).body.fullName).toBe('Дилноза Юсупова');
    const row = await t.prisma.auditLog.findFirst({ where: { action: 'user.name_change', entityId: m.user.id } });
    expect(row).toBeTruthy();
  });

  it('worker: her account and her card get the new name; too short is refused', async () => {
    const admin = await staffActor(t, 'ADMIN');
    const reg = await registerViaBot(t, { name: 'Малика Каримова' });
    const w = await approveAndLoginWorker(t, admin.api, reg.phone);
    await w.api.patch('/v1/auth/me', { fullName: 'Малика Рашидова' }).expect(200);
    const card = await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.workerId }, include: { user: true } });
    expect(card.fullName).toBe('Малика Рашидова');
    expect(card.user?.fullName).toBe('Малика Рашидова');
    await w.api.patch('/v1/auth/me', { fullName: ' М ' }).expect(400);
  });

  it('needs a signed-in user', async () => {
    const anon = (await import('supertest')).default(t.app.getHttpServer());
    expect((await anon.patch('/v1/auth/me').send({ fullName: 'Кто-то Там' })).status).toBe(401);
  });
});
