import { adminActor, approveAndLoginWorker, createTestApp, jpeg, registerViaBot, TestApp } from './support/app';

describe('collateral (залог): declared in Telegram, held by ADMIN, returned with confirmation', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  async function setup(type: 'MONEY' | 'ITEM' = 'MONEY') {
    const admin = await adminActor(t);
    const reg = await registerViaBot(t, { type });
    const w = await admin.api.get(`/v1/workers?q=${reg.phone.slice(-7)}`).expect(200);
    const collateralId = w.body.items[0].collateral.id as string;
    return { admin, workerId: w.body.items[0].id as string, collateralId, phone: reg.phone };
  }

  it('receive: PENDING → HELD with receiver, value and location; history keeps every step; realtime + audit', async () => {
    const { admin, collateralId } = await setup('ITEM');
    const before = t.events.length;
    const res = await admin.api.post(`/v1/collaterals/${collateralId}/receive`, { estimatedValue: '4200000', storageLocation: 'Сейф A, полка 2', note: 'Принято лично' }).expect(200);
    expect(res.body).toMatchObject({ status: 'HELD', estimatedValue: '4200000', storageLocation: 'Сейф A, полка 2' });
    expect(res.body.receivedAt).not.toBeNull();
    expect(res.body.history.map((h: { type: string }) => h.type)).toEqual(['DECLARED', 'RECEIVED']);
    expect(res.body.history[1].actorLabel).toBe('Admin Owner');
    expect(t.events.slice(before).map((e) => e.type)).toEqual(['collateral.updated']);
    const audit = await t.prisma.auditLog.findFirst({ where: { entityId: collateralId, action: 'collateral.receive' } });
    expect(audit?.before).toMatchObject({ status: 'PENDING' });
    expect(audit?.after).toMatchObject({ status: 'HELD' });
    await admin.api.post(`/v1/collaterals/${collateralId}/receive`, {}).expect(409); // already held
  });

  it('return: only from HELD, needs the worker confirmation, is terminal', async () => {
    const { admin, collateralId } = await setup();
    await admin.api.post(`/v1/collaterals/${collateralId}/return`, { note: 'вернули', workerConfirmed: true }).expect(409); // still PENDING
    await admin.api.post(`/v1/collaterals/${collateralId}/receive`, {}).expect(200);
    await admin.api.post(`/v1/collaterals/${collateralId}/return`, { note: 'без подтверждения' }).expect(400);
    await admin.api.post(`/v1/collaterals/${collateralId}/return`, { note: 'x', workerConfirmed: false }).expect(400);
    const res = await admin.api.post(`/v1/collaterals/${collateralId}/return`, { note: 'Вернули лично, расписалась', workerConfirmed: true }).expect(200);
    expect(res.body).toMatchObject({ status: 'RETURNED', returnNote: 'Вернули лично, расписалась' });
    expect(res.body.history.map((h: { type: string }) => h.type)).toEqual(['DECLARED', 'RECEIVED', 'RETURNED']);
    await admin.api.post(`/v1/collaterals/${collateralId}/return`, { note: 'ещё раз', workerConfirmed: true }).expect(409);
  });

  it('CONCURRENCY: two simultaneous returns — exactly one wins (row lock)', async () => {
    const { admin, collateralId } = await setup();
    await admin.api.post(`/v1/collaterals/${collateralId}/receive`, {}).expect(200);
    const body = { note: 'гонка', workerConfirmed: true };
    const results = await Promise.all([1, 2, 3].map(() => admin.api.post(`/v1/collaterals/${collateralId}/return`, body)));
    expect(results.map((r) => r.status).sort()).toEqual([200, 409, 409]);
    expect(await t.prisma.collateralHistory.count({ where: { collateralId, type: 'RETURNED' } })).toBe(1);
  });

  it('ADMIN photos: stored in MinIO, attached once for identical content, signed URLs, history entry', async () => {
    const { admin, collateralId } = await setup('ITEM');
    const img = await jpeg({ r: 10, g: 200, b: 10 });
    const r1 = await admin.api.upload(`/v1/collaterals/${collateralId}/photos`, img, 'p.jpg', { caption: 'спереди' }).expect(201);
    const r2 = await admin.api.upload(`/v1/collaterals/${collateralId}/photos`, img, 'p.jpg').expect(201); // offline retry
    expect(r2.body.photos.length).toBe(r1.body.photos.length);
    const other = await admin.api.upload(`/v1/collaterals/${collateralId}/photos`, await jpeg({ r: 1, g: 1, b: 250 }), 'q.jpg').expect(201);
    expect(other.body.photos.length).toBe(r1.body.photos.length + 1);
    expect(other.body.photos[0].file.thumbUrl).toContain('/v1/files/');
    expect(other.body.history.filter((h: { type: string }) => h.type === 'PHOTO_ADDED')).toHaveLength(2);
    await admin.api.upload(`/v1/collaterals/${collateralId}/photos`, Buffer.from('not an image'), 'evil.jpg').expect(422);
  });

  it('a worker sees only her own collateral, including the declared photos', async () => {
    const admin = await adminActor(t);
    const a = await registerViaBot(t, { type: 'ITEM' });
    await registerViaBot(t, { type: 'MONEY' });
    const wa = await approveAndLoginWorker(t, admin.api, a.phone);
    const mine = await wa.api.get('/v1/workers/me/collateral').expect(200);
    expect(mine.body.items).toHaveLength(1);
    expect(mine.body.items[0]).toMatchObject({ type: 'ITEM', status: 'HELD', description: 'Золотое кольцо 585' }); // approved with collateralReceived
    expect(mine.body.items[0].photos).toHaveLength(1);
  });

  it('HISTORY IS IMMUTABLE IN THE DATABASE: no update, delete or truncate — even through raw SQL', async () => {
    const { collateralId } = await setup();
    const h = await t.prisma.collateralHistory.findFirstOrThrow({ where: { collateralId } });
    await expect(t.prisma.collateralHistory.update({ where: { id: h.id }, data: { note: 'tampered' } })).rejects.toThrow(/append-only/);
    await expect(t.prisma.collateralHistory.delete({ where: { id: h.id } })).rejects.toThrow(/append-only/);
    await expect(t.prisma.$executeRawUnsafe(`DELETE FROM collateral_history WHERE id = '${h.id}'::uuid`)).rejects.toThrow(/append-only/);
    await expect(t.prisma.$executeRawUnsafe('TRUNCATE collateral_history')).rejects.toThrow(/append-only/);
  });

  it('list filters by worker and status', async () => {
    const { admin, workerId, collateralId } = await setup();
    const held = await admin.api.get(`/v1/collaterals?workerId=${workerId}&status=HELD`).expect(200);
    expect(held.body.items).toHaveLength(0);
    const pending = await admin.api.get(`/v1/collaterals?workerId=${workerId}&status=PENDING`).expect(200);
    expect(pending.body.items.map((c: { id: string }) => c.id)).toEqual([collateralId]);
  });
});
