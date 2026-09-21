import type { RealtimeEnvelope } from '@yusmus/shared';
import { io, type Socket } from 'socket.io-client';
import request from 'supertest';
import { PayRateService } from '../src/settings/pay-rate.service';
import { adminActor, approveAndLoginWorker, createTestApp, registerViaBot, TestApp } from './support/app';

function connect(url: string, token: string): Promise<{ socket: Socket; events: RealtimeEnvelope[] }> {
  return new Promise((resolve, reject) => {
    const socket = io(url, { auth: { token }, transports: ['websocket'], reconnection: false });
    const events: RealtimeEnvelope[] = [];
    socket.on('event', (e: RealtimeEnvelope) => events.push(e));
    socket.on('ready', () => resolve({ socket, events }));
    socket.on('unauthorized', () => reject(new Error('socket refused')));
  });
}
const until = async (cond: () => boolean, ms = 3000) => {
  const end = Date.now() + ms;
  while (!cond() && Date.now() < end) await new Promise((r) => setTimeout(r, 25));
  return cond();
};

describe('one global price for a 9 m kit: ADMIN can change it at any moment, it changes for everybody (D-027)', () => {
  let t: TestApp;
  let url: string;
  const sockets: Socket[] = [];
  beforeAll(async () => {
    t = await createTestApp();
    await t.app.listen(0, '127.0.0.1');
    const addr = t.app.getHttpServer().address();
    url = `http://127.0.0.1:${typeof addr === 'object' && addr ? addr.port : 0}`;
  });
  afterAll(async () => {
    sockets.forEach((s) => s.close());
    await t.close();
  });

  it('starts at 30 000 UZS per 9 m; ADMIN and WORKER read the same price; anonymous cannot', async () => {
    const admin = await adminActor(t);
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, admin.api, reg.phone);

    const a = await admin.api.get('/v1/settings/pay-rate').expect(200);
    expect(a.body).toMatchObject({ ratePerKit: '30000', kitMeters: 9 });
    const w = await worker.api.get('/v1/settings/pay-rate').expect(200);
    expect(w.body.ratePerKit).toBe('30000');
    await request(t.app.getHttpServer()).get('/v1/settings/pay-rate').expect(401);
  });

  it('only ADMIN can change it; a worker gets 403 and the price stays', async () => {
    const admin = await adminActor(t);
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, admin.api, reg.phone);
    await worker.api.get('/v1/settings/pay-rate/history').expect(403);
    await request(t.app.getHttpServer()).put('/v1/settings/pay-rate').set('Authorization', `Bearer ${worker.session.accessToken}`).send({ ratePerKit: 99999 }).expect(403);
    expect((await admin.api.get('/v1/settings/pay-rate')).body.ratePerKit).toBe('30000');
  });

  it('ADMIN changes the price: everybody reads the new value, history keeps who/when/from/to, audit is written', async () => {
    const admin = await adminActor(t);
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, admin.api, reg.phone);

    const put = await request(t.app.getHttpServer()).put('/v1/settings/pay-rate').set('Authorization', `Bearer ${admin.session.accessToken}`).send({ ratePerKit: '35000', note: 'Индексация' }).expect(200);
    expect(put.body).toMatchObject({ ratePerKit: '35000', changed: true, kitMeters: 9 });
    expect((await worker.api.get('/v1/settings/pay-rate')).body.ratePerKit).toBe('35000'); // the worker sees it at once
    expect((await admin.api.get('/v1/settings/pay-rate')).body.ratePerKit).toBe('35000');

    const hist = (await admin.api.get('/v1/settings/pay-rate/history').expect(200)).body.items as { ratePerKit: string; previousRatePerKit: string | null; changedBy: string | null; note: string | null }[];
    expect(hist[0]).toMatchObject({ ratePerKit: '35000', previousRatePerKit: '30000', changedBy: 'Admin Owner', note: 'Индексация' });
    expect(hist[hist.length - 1]).toMatchObject({ ratePerKit: '30000', previousRatePerKit: null, changedBy: null }); // the seeded start

    const audit = await t.prisma.auditLog.findFirstOrThrow({ where: { action: 'pay_rate.change' }, orderBy: { id: 'desc' } });
    expect(audit).toMatchObject({ actorId: admin.user.id, actorRole: 'ADMIN', entity: 'PayRate' });
    expect(audit.after).toMatchObject({ ratePerKit: '35000' });

    // and back to 30 000: "at any moment", any number of times
    await request(t.app.getHttpServer()).put('/v1/settings/pay-rate').set('Authorization', `Bearer ${admin.session.accessToken}`).send({ ratePerKit: 30000 }).expect(200);
    expect((await worker.api.get('/v1/settings/pay-rate')).body.ratePerKit).toBe('30000');
  });

  it('the same price again is a no-op (no history row, no event); nonsense is rejected', async () => {
    const admin = await adminActor(t);
    const put = (body: object) => request(t.app.getHttpServer()).put('/v1/settings/pay-rate').set('Authorization', `Bearer ${admin.session.accessToken}`).send(body);
    const before = await t.prisma.payRateChange.count();
    const events = t.events.length;
    const same = await put({ ratePerKit: 30000 }).expect(200);
    expect(same.body.changed).toBe(false);
    expect(await t.prisma.payRateChange.count()).toBe(before);
    expect(t.events.length).toBe(events);

    for (const bad of [0, -5, 1.5, '12.5', 'abc', '', 10_000_001, '99999999999999', null]) {
      const res = await put({ ratePerKit: bad });
      expect([400, 422]).toContain(res.status);
    }
    await put({}).expect(400);
    expect(await t.prisma.payRateChange.count()).toBe(before);
  });

  it('a retried request with the same Idempotency-Key changes the price once', async () => {
    const admin = await adminActor(t);
    const before = await t.prisma.payRateChange.count();
    const send = () => request(t.app.getHttpServer()).put('/v1/settings/pay-rate').set('Authorization', `Bearer ${admin.session.accessToken}`).set('Idempotency-Key', 'rate-change-0001-abcd').send({ ratePerKit: 32000 });
    const first = await send().expect(200);
    const again = await send().expect(200);
    expect(again.body).toEqual(first.body);
    expect(await t.prisma.payRateChange.count()).toBe(before + 1);
    await request(t.app.getHttpServer()).put('/v1/settings/pay-rate').set('Authorization', `Bearer ${admin.session.accessToken}`).send({ ratePerKit: 30000 }).expect(200);
  });

  it('concurrent changes never fork the history: every row points at the one before it', async () => {
    const admin = await adminActor(t);
    const rates = [31000, 32000, 33000, 34000, 35000, 36000];
    await Promise.all(rates.map((r) => request(t.app.getHttpServer()).put('/v1/settings/pay-rate').set('Authorization', `Bearer ${admin.session.accessToken}`).send({ ratePerKit: r }).expect(200)));
    const rows = await t.prisma.payRateChange.findMany({ orderBy: { seq: 'asc' } });
    for (let i = 1; i < rows.length; i++) expect(rows[i].previousRatePerKit).toBe(rows[i - 1].ratePerKit);
    expect(rows[0].previousRatePerKit).toBeNull();
    const current = await admin.api.get('/v1/settings/pay-rate');
    expect(current.body.ratePerKit).toBe(rows[rows.length - 1].ratePerKit.toString());
    await request(t.app.getHttpServer()).put('/v1/settings/pay-rate').set('Authorization', `Bearer ${admin.session.accessToken}`).send({ ratePerKit: 30000 }).expect(200);
  });

  it('realtime: a change reaches every ADMIN and EVERY worker at once (not just one worker)', async () => {
    const admin = await adminActor(t);
    const regA = await registerViaBot(t);
    const regB = await registerViaBot(t);
    const wa = await approveAndLoginWorker(t, admin.api, regA.phone);
    const wb = await approveAndLoginWorker(t, admin.api, regB.phone);
    const [ca, cw1, cw2] = await Promise.all([connect(url, admin.session.accessToken), connect(url, wa.session.accessToken), connect(url, wb.session.accessToken)]);
    sockets.push(ca.socket, cw1.socket, cw2.socket);

    await request(t.app.getHttpServer()).put('/v1/settings/pay-rate').set('Authorization', `Bearer ${admin.session.accessToken}`).send({ ratePerKit: 40000 }).expect(200);
    for (const c of [ca, cw1, cw2]) {
      expect(await until(() => c.events.some((e) => e.type === 'pay_rate.changed'))).toBe(true);
      expect(c.events.find((e) => e.type === 'pay_rate.changed')!.data).toMatchObject({ ratePerKit: '40000', previousRatePerKit: '30000' });
      expect(c.events.filter((e) => e.type === 'pay_rate.changed')).toHaveLength(1); // no duplicates
    }
    await request(t.app.getHttpServer()).put('/v1/settings/pay-rate').set('Authorization', `Bearer ${admin.session.accessToken}`).send({ ratePerKit: 30000 }).expect(200);
  });

  it('open work follows the current price, accepted work keeps its amount (the rule M5 builds on)', async () => {
    const admin = await adminActor(t);
    const rates = t.app.get(PayRateService);
    const at = async (cm: number) => (await rates.earning(t.prisma, cm)).amount;
    expect(await at(900)).toBe(30000n);
    expect(await at(1800)).toBe(60000n);
    expect(await at(2700)).toBe(90000n);
    await request(t.app.getHttpServer()).put('/v1/settings/pay-rate').set('Authorization', `Bearer ${admin.session.accessToken}`).send({ ratePerKit: 45000 }).expect(200);
    expect(await at(1800)).toBe(90000n); // the same 18 m, evaluated at the new price
    await request(t.app.getHttpServer()).put('/v1/settings/pay-rate').set('Authorization', `Bearer ${admin.session.accessToken}`).send({ ratePerKit: 30000 }).expect(200);
  });

  it('the history table is append-only in the database itself', async () => {
    const row = await t.prisma.payRateChange.findFirstOrThrow({ orderBy: { seq: 'asc' } });
    expect(row).toMatchObject({ ratePerKit: 30000n, changedById: null });
    await expect(t.prisma.payRateChange.update({ where: { id: row.id }, data: { ratePerKit: 1n } })).rejects.toThrow(/append-only/);
    await expect(t.prisma.payRateChange.delete({ where: { id: row.id } })).rejects.toThrow(/append-only/);
    await expect(t.prisma.$executeRawUnsafe('TRUNCATE pay_rate_changes')).rejects.toThrow(/append-only/);
    await expect(t.prisma.payRateChange.create({ data: { ratePerKit: 0n } })).rejects.toThrow(/rate_positive/);
  });
});
