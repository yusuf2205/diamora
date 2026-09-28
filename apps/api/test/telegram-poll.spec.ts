import request from 'supertest';
import { randomUUID } from 'node:crypto';
import { approveAndLoginWorker, createTestApp, registerViaBot, superAdminActor, TestApp } from './support/app';

/** Web / PWA login: the browser tab that started the Telegram login polls until she pressed Start in the bot. */
describe('Telegram login from a browser (poll)', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('WAITING before Start, a real session right after, spent after one use, bound to the same browser', async () => {
    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    await approveAndLoginWorker(t, admin.api, reg.phone);
    const device = { installId: randomUUID(), platform: 'WEB', name: 'Chrome', appVersion: 'web' };
    const http = () => request(t.app.getHttpServer());

    const s = await http().post('/v1/auth/telegram/session').send({ device }).expect(200);
    const sessionToken = new URL(s.body.deepLink).searchParams.get('start')!;
    expect((await http().post('/v1/auth/telegram/poll').send({ sessionToken, device }).expect(200)).body.status).toBe('WAITING');

    // she opens the link and presses Start in the bot
    await t.registration.process(reg.ctx, { kind: 'command', command: 'start', payload: sessionToken });

    await http().post('/v1/auth/telegram/poll').send({ sessionToken, device: { ...device, installId: randomUUID() } }).expect(401); // another browser
    const ok = await http().post('/v1/auth/telegram/poll').send({ sessionToken, device }).expect(200);
    expect(ok.body.accessToken).toBeTruthy();
    expect(ok.body.user.role).toBe('WORKER');
    await http().get('/v1/work/current').set('Authorization', `Bearer ${ok.body.accessToken}`).expect(200);
    await http().post('/v1/auth/telegram/poll').send({ sessionToken, device }).expect(401); // one login per session
  });

  it('a person still answering the bot is NOT_REGISTERED (the page keeps waiting)', async () => {
    const device = { installId: randomUUID(), platform: 'WEB', name: 'Chrome', appVersion: 'web' };
    const s = await request(t.app.getHttpServer()).post('/v1/auth/telegram/session').send({ device }).expect(200);
    const sessionToken = new URL(s.body.deepLink).searchParams.get('start')!;
    const tg = { telegramUserId: BigInt(987650000 + Math.floor(Math.random() * 1000)), chatId: 1n };
    await t.registration.process(tg, { kind: 'command', command: 'start', payload: sessionToken });
    const r = await request(t.app.getHttpServer()).post('/v1/auth/telegram/poll').send({ sessionToken, device }).expect(200);
    expect(r.body.status).toBe('NOT_REGISTERED');
  });
});
