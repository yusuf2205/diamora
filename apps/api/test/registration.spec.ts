import { action, createStaff, createTestApp, jpeg, nextTelegramId, registerViaBot, text, uniquePhone, TestApp } from './support/app';

describe('Telegram registration (business logic behind the bot)', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('MONEY registration creates a pending worker, a declared collateral, GPS, history, audit — and tells ADMIN in realtime AFTER commit', async () => {
    const before = t.events.length;
    const { phone, done } = await registerViaBot(t, { name: 'Малика Каримова' });
    expect(done.prompt).toBe('SUBMITTED');

    const w = await t.prisma.workerProfile.findUniqueOrThrow({ where: { phone }, include: { collaterals: { include: { history: true } }, locations: true } });
    expect(w).toMatchObject({ fullName: 'Малика Каримова', status: 'PENDING_APPROVAL', userId: null });
    expect(w.code).toMatch(/^W-\d{4}$/);
    expect(w.latitude!.toNumber()).toBeCloseTo(41.2995, 4);
    expect(w.locationReceivedAt).not.toBeNull();
    expect(w.locations).toHaveLength(1);
    expect(w.locations[0].source).toBe('TELEGRAM');
    expect(w.collaterals).toHaveLength(1);
    expect(w.collaterals[0]).toMatchObject({ type: 'MONEY', status: 'PENDING' });
    expect(w.collaterals[0].amount).toBe(1_500_000n);
    expect(w.collaterals[0].history.map((h) => h.type)).toEqual(['DECLARED']);

    const audit = await t.prisma.auditLog.findFirst({ where: { entityId: w.id, action: 'worker.register' } });
    expect(audit?.actorRole).toBe('WORKER');
    // the draft is gone
    expect(await t.prisma.registrationDraft.count({ where: { telegramUserId: w.telegramUserId } })).toBe(0);

    const fresh = t.events.slice(before);
    expect(fresh.map((e) => e.type)).toEqual(['worker.created', 'collateral.created']);
    expect(fresh[0].data).toMatchObject({ workerId: w.id, code: w.code, status: 'PENDING_APPROVAL' });
  });

  it('ITEM registration stores the photos in the object store and attaches them to the collateral', async () => {
    const { phone } = await registerViaBot(t, { type: 'ITEM' });
    const w = await t.prisma.workerProfile.findUniqueOrThrow({ where: { phone }, include: { collaterals: { include: { photos: true } } } });
    const c = w.collaterals[0];
    expect(c).toMatchObject({ type: 'ITEM', description: 'Золотое кольцо 585', status: 'PENDING', amount: null });
    expect(c.photos).toHaveLength(1);
    const asset = await t.prisma.fileAsset.findUniqueOrThrow({ where: { id: c.photos[0].fileId } });
    expect(asset).toMatchObject({ bucket: 'collateral', mimeType: 'image/jpeg' });
  });

  it('state lives in PostgreSQL: a half-filled registration survives a restart and continues where it stopped', async () => {
    const tgId = nextTelegramId();
    const ctx = { telegramUserId: BigInt(tgId), chatId: BigInt(tgId) };
    await t.registration.process(ctx, { kind: 'command', command: 'start' });
    await t.registration.process(ctx, text('Гуля Юсупова'));
    const draft = await t.prisma.registrationDraft.findUniqueOrThrow({ where: { telegramUserId: ctx.telegramUserId } });
    expect((draft.state as { step: string }).step).toBe('PHONE');
    // "restart": nothing is kept in memory; the next update just continues
    const r = await t.registration.process(ctx, { kind: 'contact', phone: uniquePhone().replace('+', ''), contactUserId: tgId });
    expect(r.prompt).toBe('ASK_SECONDARY');
    // /start on a draft restarts the flow, /cancel drops it
    expect((await t.registration.process(ctx, { kind: 'command', command: 'start' })).prompt).toBe('WELCOME');
    expect((await t.registration.process(ctx, { kind: 'command', command: 'cancel' })).prompt).toBe('CANCELLED');
    expect(await t.prisma.registrationDraft.count({ where: { telegramUserId: ctx.telegramUserId } })).toBe(0);
  });

  it('rejects a forwarded contact, validates input and keeps the same question', async () => {
    const tgId = nextTelegramId();
    const ctx = { telegramUserId: BigInt(tgId), chatId: BigInt(tgId) };
    await t.registration.process(ctx, { kind: 'command', command: 'start' });
    expect((await t.registration.process(ctx, text('1'))).error).toBe('NAME_INVALID');
    await t.registration.process(ctx, text('Малика'));
    const r = await t.registration.process(ctx, { kind: 'contact', phone: '998901112233', contactUserId: tgId + 1 });
    expect(r).toMatchObject({ prompt: 'ASK_PHONE', error: 'PHONE_NOT_OWN' });
  });

  it('an already used phone number cannot register twice (PHONE_TAKEN, flow returns to the phone step)', async () => {
    const first = await registerViaBot(t);
    const tgId = nextTelegramId();
    const ctx = { telegramUserId: BigInt(tgId), chatId: BigInt(tgId) };
    const send = (i: Parameters<typeof t.registration.process>[1]) => t.registration.process(ctx, i);
    await send({ kind: 'command', command: 'start' });
    await send(text('Другая Мастерица'));
    await send({ kind: 'contact', phone: first.phone.replace('+', ''), contactUserId: tgId });
    await send(action('skip'));
    await send({ kind: 'location', latitude: 41.3, longitude: 69.2 });
    await send(action('type_money'));
    await send(text('100000'));
    await send(action('skip'));
    const r = await send(action('confirm'));
    expect(r).toMatchObject({ prompt: 'ASK_PHONE', error: 'PHONE_TAKEN' });
    expect(await t.prisma.workerProfile.count({ where: { telegramUserId: ctx.telegramUserId } })).toBe(0);
  });

  it('a phone already belonging to a staff account is rejected at registration submit time, not only when an admin later tries to approve it (PHONE_TAKEN, message never says who owns it)', async () => {
    const staff = await createStaff(t, 'MANAGER');
    const tgId = nextTelegramId();
    const ctx = { telegramUserId: BigInt(tgId), chatId: BigInt(tgId) };
    const send = (i: Parameters<typeof t.registration.process>[1]) => t.registration.process(ctx, i);
    await send({ kind: 'command', command: 'start' });
    await send(text('Третья Мастерица'));
    await send({ kind: 'contact', phone: staff.phone.replace('+', ''), contactUserId: tgId });
    await send(action('skip'));
    await send({ kind: 'location', latitude: 41.3, longitude: 69.2 });
    await send(action('type_money'));
    await send(text('100000'));
    await send(action('skip'));
    const r = await send(action('confirm'));
    expect(r).toMatchObject({ prompt: 'ASK_PHONE', error: 'PHONE_TAKEN' });
    // no orphaned WorkerProfile left dangling for an admin to trip over at approval time
    expect(await t.prisma.workerProfile.count({ where: { telegramUserId: ctx.telegramUserId } })).toBe(0);
  });

  it('a failed photo download does not advance the flow; photos sent as an album in parallel are all stored (advisory lock)', async () => {
    const tgId = nextTelegramId();
    const ctx = { telegramUserId: BigInt(tgId), chatId: BigInt(tgId) };
    const send = (i: Parameters<typeof t.registration.process>[1]) => t.registration.process(ctx, i);
    await send({ kind: 'command', command: 'start' });
    await send(text('Альбом Тест'));
    await send({ kind: 'contact', phone: uniquePhone().replace('+', ''), contactUserId: tgId });
    await send(action('skip'));
    await send({ kind: 'location', latitude: 41.3, longitude: 69.2 });
    await send(action('type_item'));
    await send(text('Серебряная цепочка'));

    const failed = await send({ kind: 'photo', download: async () => { throw new Error('telegram down'); } });
    expect(failed).toMatchObject({ prompt: 'ASK_PHOTOS', error: 'PHOTO_FAILED' });
    expect((await send(action('photos_done'))).error).toBe('PHOTO_REQUIRED'); // counter did not move

    const imgs = await Promise.all([1, 2, 3, 4, 5].map((i) => jpeg({ r: 20 * i, g: 90, b: 200 - 20 * i })));
    await Promise.all(imgs.map((img) => send({ kind: 'photo', download: async () => ({ buffer: img }) })));
    const draft = await t.prisma.registrationDraft.findUniqueOrThrow({ where: { telegramUserId: ctx.telegramUserId } });
    expect(draft.photoFileIds).toHaveLength(5);
    expect((draft.state as { data: { photoCount: number } }).data.photoCount).toBe(5);
  });

  it('a registered worker is shown her status and can refresh her GPS point (realtime to ADMIN)', async () => {
    const { ctx, send, phone } = await registerViaBot(t);
    expect((await send(text('привет'))).prompt).toBe('STATUS_PENDING');
    expect((await send({ kind: 'command', command: 'start' })).prompt).toBe('STATUS_PENDING');
    const before = t.events.length;
    expect((await send({ kind: 'location', latitude: 41.35, longitude: 69.3 })).prompt).toBe('LOCATION_UPDATED');
    const w = await t.prisma.workerProfile.findUniqueOrThrow({ where: { phone }, include: { locations: true } });
    expect(w.latitude!.toNumber()).toBeCloseTo(41.35, 3);
    expect(w.locations).toHaveLength(2);
    expect(t.events.slice(before).map((e) => e.type)).toEqual(['worker.location.updated']);
    expect(ctx.telegramUserId).toBe(w.telegramUserId);
  });
});
