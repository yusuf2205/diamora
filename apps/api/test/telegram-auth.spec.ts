import request from 'supertest';
import { sha256 } from '../src/common/sequence';
import {
  adminActor, approveAndLoginWorker, createTestApp, nextTelegramId, registerViaBot, telegramLoginTicket, TestApp, uniquePhone,
} from './support/app';

const device = (suffix = 'device-1') => ({ installId: `tg-test-${suffix}`, platform: 'ANDROID' });
const post = (t: TestApp, path: string, body: object) => request(t.app.getHttpServer()).post(path).send(body);

describe('WORKER Telegram-only login (§ critical auth change): no phone/password/OTP flow exists for WORKER any more', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('the old phone+code worker endpoints are gone', async () => {
    await post(t, '/v1/auth/worker/code', { phone: uniquePhone() }).expect(404);
    await post(t, '/v1/auth/worker/login', { phone: uniquePhone(), code: '123456', device: device() }).expect(404);
  });

  it('opens a login session: a one-time /start deep link to the real bot, never a permanent identifier', async () => {
    const res = await post(t, '/v1/auth/telegram/session', { device: device() }).expect(200);
    expect(res.body.deepLink).toMatch(/^https:\/\/t\.me\/[\w]+\?start=[\w-]{20,}$/);
    expect(new Date(res.body.expiresAt).getTime()).toBeGreaterThan(Date.now());
  });

  it('a returning ACTIVE worker: /start <token> issues a ticket in the same reply — one tap, no second round trip', async () => {
    const admin = await adminActor(t);
    const { phone } = await registerViaBot(t);
    const w = await approveAndLoginWorker(t, admin.api, phone); // already exercises the full session->ticket->exchange path once
    const worker = await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.workerId } });

    const { ticket } = await telegramLoginTicket(t, worker.telegramUserId, worker.telegramChatId);
    const res = await post(t, '/v1/auth/telegram/exchange', { ticket, device: device('second-login') }).expect(200);
    expect(res.body.user).toMatchObject({ role: 'WORKER', workerId: w.workerId });
    expect(res.body.accessToken).toBeTruthy();
  });

  it('a brand-new worker: the whole questionnaire, reached via the app deep link, ends in a ticket whose exchange reports PENDING_APPROVAL (no tokens, no session)', async () => {
    const sessionRes = await post(t, '/v1/auth/telegram/session', { device: device() }).expect(200);
    const startToken = new URL(sessionRes.body.deepLink).searchParams.get('start')!;
    const tgId = nextTelegramId();
    const ctx = { telegramUserId: BigInt(tgId), chatId: BigInt(tgId) };
    const send = (i: Parameters<TestApp['registration']['process']>[1]) => t.registration.process(ctx, i);

    expect((await send({ kind: 'command', command: 'start', payload: startToken })).prompt).toBe('LOGIN_ASK_PHONE'); // first: is she known?
    expect((await send({ kind: 'contact', phone: uniquePhone().replace('+', ''), contactUserId: tgId })).prompt).toBe('WELCOME'); // nobody: register
    expect((await send({ kind: 'text', text: 'Новая Мастерица' })).prompt).toBe('ASK_LOCATION'); // the phone is not asked again
    await send({ kind: 'location', latitude: 41.3, longitude: 69.24 });
    await send({ kind: 'action', action: 'type_money' });
    await send({ kind: 'text', text: '1 000 000' });
    await send({ kind: 'action', action: 'skip' });
    const done = await send({ kind: 'action', action: 'confirm' });

    expect(done.prompt).toBe('SUBMITTED');
    expect(done.telegramHandoffUrl).toBeTruthy();
    const ticket = new URL(done.telegramHandoffUrl!).searchParams.get('t')!;
    const res = await post(t, '/v1/auth/telegram/exchange', { ticket, device: device() }).expect(200);
    expect(res.body).toEqual({ status: 'PENDING_APPROVAL' });
  });

  it('staff sign in through the bot too: the first time by sharing their phone, after that straight away', async () => {
    const admin = await adminActor(t);
    const me = await t.prisma.user.findUniqueOrThrow({ where: { id: admin.user.id } });
    const tgId = nextTelegramId();
    const ctx = { telegramUserId: BigInt(tgId), chatId: BigInt(tgId) };
    const startToken = async () => new URL((await post(t, '/v1/auth/telegram/session', { device: device('staff') }).expect(200)).body.deepLink).searchParams.get('start')!;

    // the first time: the bot does not know this Telegram -> asks the phone -> recognises the admin
    const first = await startToken();
    expect((await t.registration.process(ctx, { kind: 'command', command: 'start', payload: first })).prompt).toBe('LOGIN_ASK_PHONE');
    expect((await t.registration.process(ctx, { kind: 'contact', phone: me.phone, contactUserId: tgId + 1 })).error).toBe('PHONE_NOT_OWN'); // someone else's contact
    const linked = await t.registration.process(ctx, { kind: 'contact', phone: me.phone.replace('+', ''), contactUserId: tgId });
    expect(linked.prompt).toBe('STAFF_LOGIN');
    // the app was polling: it is signed in without even tapping the button
    const polled = await post(t, '/v1/auth/telegram/poll', { sessionToken: first, device: device('staff') }).expect(200);
    expect(polled.body.user).toMatchObject({ id: me.id, role: me.role });
    expect(await t.prisma.workerProfile.findUnique({ where: { telegramUserId: BigInt(tgId) } })).toBeNull(); // no worker made of an admin

    // next time: one reply with the button, no questions
    const again = await t.registration.process(ctx, { kind: 'command', command: 'start', payload: await startToken() });
    expect(again.prompt).toBe('STAFF_LOGIN');
    const ticket = new URL(again.telegramHandoffUrl!).searchParams.get('t')!;
    const res = await post(t, '/v1/auth/telegram/exchange', { ticket, device: device('staff') }).expect(200);
    expect(res.body.user).toMatchObject({ id: me.id, role: me.role });
    expect(res.body.accessToken).toBeTruthy();
  });

  it("a phone that belongs to a worker on another Telegram account is never taken over", async () => {
    const { phone } = await registerViaBot(t);
    const tgId = nextTelegramId();
    const ctx = { telegramUserId: BigInt(tgId), chatId: BigInt(tgId) };
    const startToken = new URL((await post(t, '/v1/auth/telegram/session', { device: device() }).expect(200)).body.deepLink).searchParams.get('start')!;
    await t.registration.process(ctx, { kind: 'command', command: 'start', payload: startToken });
    const r = await t.registration.process(ctx, { kind: 'contact', phone: phone.replace('+', ''), contactUserId: tgId });
    expect(r.prompt).toBe('LINKED_ELSEWHERE');
    expect(r.telegramHandoffUrl).toBeUndefined();
  });

  it('an organic bot conversation (no app session) never gets a handoff button', async () => {
    const { phone } = await registerViaBot(t, { name: 'Органика Без Приложения' });
    const w = await t.prisma.workerProfile.findUniqueOrThrow({ where: { phone } });
    const reply = await t.registration.process({ telegramUserId: w.telegramUserId, chatId: w.telegramChatId }, { kind: 'text', text: 'привет' });
    expect(reply.prompt).toBe('STATUS_PENDING');
    expect(reply.telegramHandoffUrl).toBeUndefined();
  });

  it('a REJECTED worker: exchange reports REJECTED with the reason, never a session', async () => {
    const admin = await adminActor(t);
    const { phone } = await registerViaBot(t);
    const workerRow = await t.prisma.workerProfile.findUniqueOrThrow({ where: { phone } });
    await admin.api.post(`/v1/workers/${workerRow.id}/reject`, { reason: 'Не подходит' }).expect(201);

    const { ticket } = await telegramLoginTicket(t, workerRow.telegramUserId, workerRow.telegramChatId);
    const res = await post(t, '/v1/auth/telegram/exchange', { ticket, device: device() }).expect(200);
    expect(res.body).toEqual({ status: 'REJECTED', rejectedReason: 'Не подходит' });
  });

  it('a PAUSED worker: exchange reports PAUSED, never a session', async () => {
    const admin = await adminActor(t);
    const { phone } = await registerViaBot(t);
    const w = await approveAndLoginWorker(t, admin.api, phone);
    await admin.api.patch(`/v1/workers/${w.workerId}`, { status: 'PAUSED' }).expect(200);
    const workerRow = await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.workerId } });

    const { ticket } = await telegramLoginTicket(t, workerRow.telegramUserId, workerRow.telegramChatId);
    const res = await post(t, '/v1/auth/telegram/exchange', { ticket, device: device() }).expect(200);
    expect(res.body).toEqual({ status: 'PAUSED' });
  });

  it('a disabled staff-side User (status SUSPENDED) is rejected even though the WorkerProfile itself is ACTIVE', async () => {
    const admin = await adminActor(t);
    const { phone } = await registerViaBot(t);
    const w = await approveAndLoginWorker(t, admin.api, phone);
    await t.prisma.user.update({ where: { id: (await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.workerId } })).userId! }, data: { status: 'SUSPENDED' } });
    const workerRow = await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.workerId } });

    const { ticket } = await telegramLoginTicket(t, workerRow.telegramUserId, workerRow.telegramChatId);
    const res = await post(t, '/v1/auth/telegram/exchange', { ticket, device: device() }).expect(200);
    expect(res.body).toEqual({ status: 'PAUSED' });
  });

  it('an expired ticket is rejected (fail closed)', async () => {
    const admin = await adminActor(t);
    const { phone } = await registerViaBot(t);
    const w = await approveAndLoginWorker(t, admin.api, phone);
    const workerRow = await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.workerId } });
    const session = await t.prisma.telegramLoginSession.create({
      data: { tokenHash: sha256('expired-session-token'), installId: 'x', telegramUserId: workerRow.telegramUserId, chatId: workerRow.telegramChatId, linkedAt: new Date(), expiresAt: new Date(Date.now() + 60_000) },
    });
    const raw = 'expired-ticket-raw-token-0001';
    await t.prisma.telegramHandoffTicket.create({
      data: { tokenHash: sha256(raw), sessionId: session.id, telegramUserId: workerRow.telegramUserId, workerId: w.workerId, expiresAt: new Date(Date.now() - 1000) },
    });
    const res = await post(t, '/v1/auth/telegram/exchange', { ticket: raw, device: device() });
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('TICKET_INVALID');
  });

  it('a consumed ticket cannot be replayed', async () => {
    const admin = await adminActor(t);
    const { phone } = await registerViaBot(t);
    const w = await approveAndLoginWorker(t, admin.api, phone);
    const workerRow = await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.workerId } });
    const { ticket } = await telegramLoginTicket(t, workerRow.telegramUserId, workerRow.telegramChatId);
    await post(t, '/v1/auth/telegram/exchange', { ticket, device: device('first') }).expect(200);
    const replay = await post(t, '/v1/auth/telegram/exchange', { ticket, device: device('second') });
    expect(replay.status).toBe(401);
    expect(replay.body.error.code).toBe('TICKET_INVALID');
  });

  it('a random, made-up ticket is rejected — never enumerable, never reveals whether it once existed', async () => {
    const res = await post(t, '/v1/auth/telegram/exchange', { ticket: 'totally-made-up-ticket-value-xyz', device: device() });
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('TICKET_INVALID');
  });

  it("a token already linked to one Telegram identity never re-links to another (a forwarded/leaked /start link is useless)", async () => {
    const sessionRes = await post(t, '/v1/auth/telegram/session', { device: device() }).expect(200);
    const startToken = new URL(sessionRes.body.deepLink).searchParams.get('start')!;
    const idA = nextTelegramId();
    const idB = nextTelegramId();
    const firstReply = await t.registration.process({ telegramUserId: BigInt(idA), chatId: BigInt(idA) }, { kind: 'command', command: 'start', payload: startToken });
    expect(firstReply.telegramHandoffUrl).toBeUndefined(); // brand-new person A: no worker yet, just the questionnaire starts
    const session = await t.prisma.telegramLoginSession.findUniqueOrThrow({ where: { tokenHash: sha256(startToken) } });
    expect(session.telegramUserId).toBe(BigInt(idA));

    // B tries the same leaked link — an existing ACTIVE worker impersonated as B would otherwise get a ticket
    const admin = await adminActor(t);
    const { phone } = await registerViaBot(t, { telegramId: idB });
    await approveAndLoginWorker(t, admin.api, phone);
    const workerB = await t.prisma.workerProfile.findUniqueOrThrow({ where: { phone } });
    const secondReply = await t.registration.process({ telegramUserId: workerB.telegramUserId, chatId: workerB.telegramChatId }, { kind: 'command', command: 'start', payload: startToken });
    expect(secondReply.telegramHandoffUrl).toBeUndefined();
    const sessionAfter = await t.prisma.telegramLoginSession.findUniqueOrThrow({ where: { tokenHash: sha256(startToken) } });
    expect(sessionAfter.telegramUserId).toBe(BigInt(idA)); // still A's, never overwritten by B
  });

  it('client-supplied fields beyond {ticket, device} are ignored — the session that comes back is always exactly the real worker, real role WORKER', async () => {
    const admin = await adminActor(t);
    const { phone } = await registerViaBot(t);
    const w = await approveAndLoginWorker(t, admin.api, phone);
    const workerRow = await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.workerId } });
    const { ticket } = await telegramLoginTicket(t, workerRow.telegramUserId, workerRow.telegramChatId);
    const res = await post(t, '/v1/auth/telegram/exchange', { ticket, device: device(), role: 'SUPER_ADMIN', userId: 'someone-elses-id' }).expect(200);
    expect(res.body.user.role).toBe('WORKER');
    expect(res.body.user.workerId).toBe(w.workerId);
  });
});
