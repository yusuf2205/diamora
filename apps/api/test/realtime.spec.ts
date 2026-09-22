import type { RealtimeEnvelope } from '@yusmus/shared';
import { io, type Socket } from 'socket.io-client';
import { adminActor, approveAndLoginWorker, createTestApp, registerViaBot, TestApp } from './support/app';

function connect(url: string, token: string): Promise<{ socket: Socket; events: RealtimeEnvelope[]; outcome: 'ready' | 'unauthorized' }> {
  return new Promise((resolve) => {
    const socket = io(url, { auth: { token }, transports: ['websocket'], reconnection: false });
    const events: RealtimeEnvelope[] = [];
    socket.on('event', (e: RealtimeEnvelope) => events.push(e));
    socket.on('ready', () => resolve({ socket, events, outcome: 'ready' }));
    socket.on('unauthorized', () => resolve({ socket, events, outcome: 'unauthorized' }));
    socket.on('connect_error', () => resolve({ socket, events, outcome: 'unauthorized' }));
  });
}
const until = async (cond: () => boolean, ms = 3000) => {
  const end = Date.now() + ms;
  while (!cond() && Date.now() < end) await new Promise((r) => setTimeout(r, 25));
  return cond();
};

describe('realtime (Socket.IO): events only after COMMIT, only to the right audience', () => {
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

  it('ADMIN receives worker.created in realtime when a worker registers through the bot; bad tokens are refused', async () => {
    const admin = await adminActor(t);
    const a = await connect(url, admin.session.accessToken);
    sockets.push(a.socket);
    expect(a.outcome).toBe('ready');
    const bad = await connect(url, 'not-a-token');
    sockets.push(bad.socket);
    expect(bad.outcome).toBe('unauthorized');

    const { phone } = await registerViaBot(t, { name: 'Реалтайм Тест' });
    expect(await until(() => a.events.some((e) => e.type === 'worker.created'))).toBe(true);
    const e = a.events.find((x) => x.type === 'worker.created')!;
    expect(e.data).toMatchObject({ fullName: 'Реалтайм Тест', status: 'PENDING_APPROVAL' });
    expect(e.id).toBeTruthy();
    expect(new Date(e.occurredAt).getTime()).toBeLessThanOrEqual(Date.now());
    expect(a.events.map((x) => x.type)).toContain('collateral.created');
    expect(phone).toBeTruthy();
  });

  it('a WORKER receives only her own events (worker.approved) — never admin-only events or other workers\' data', async () => {
    const admin = await adminActor(t);
    const a = await registerViaBot(t);
    const b = await registerViaBot(t);
    const ids = await Promise.all([a, b].map(async (x) => (await admin.api.get(`/v1/workers?q=${x.phone.slice(-7)}`)).body.items[0].id as string));
    // worker A is approved first so she can connect
    const wa = await approveAndLoginWorker(t, admin.api, a.phone);
    const conn = await connect(url, wa.session.accessToken);
    sockets.push(conn.socket);
    expect(conn.outcome).toBe('ready');

    await admin.api.post(`/v1/workers/${ids[1]}/approve`, { collateralReceived: true }).expect(201); // B: not for A
    await registerViaBot(t); // admin-only worker.created
    await admin.api.patch(`/v1/workers/${wa.workerId}`, { status: 'PAUSED' }).expect(200);
    await admin.api.post(`/v1/collaterals/${(await admin.api.get(`/v1/collaterals?workerId=${wa.workerId}`)).body.items[0].id}/return`, { note: 'вернули', workerConfirmed: true }).expect(200);
    expect(await until(() => conn.events.some((e) => e.type === 'collateral.updated'))).toBe(true);
    await new Promise((r) => setTimeout(r, 150));
    for (const e of conn.events) {
      expect(['collateral.updated', 'worker.approved', 'worker.rejected']).toContain(e.type);
      expect((e.data as { workerId: string }).workerId).toBe(wa.workerId);
    }
    expect(conn.events.some((e) => e.type === 'worker.created')).toBe(false);
  });

  it('revoking a session disconnects its socket immediately', async () => {
    const admin = await adminActor(t);
    const c = await connect(url, admin.session.accessToken);
    sockets.push(c.socket);
    expect(c.outcome).toBe('ready');
    const eventsBefore = t.events.length;
    await admin.api.post('/v1/auth/logout').expect(204);
    expect(await until(() => c.socket.disconnected)).toBe(true);
    // presence is best-effort and asynchronous (apps/api/src/presence): let its event land before the next test takes its baseline
    await until(() => t.events.length > eventsBefore);
  });

  it('events are published only after the transaction commits: a rolled-back registration emits nothing', async () => {
    const before = t.events.length;
    const ctx = { telegramUserId: BigInt(987654321), chatId: BigInt(987654321) };
    await t.registration.process(ctx, { kind: 'command', command: 'start' });
    await t.registration.process(ctx, { kind: 'text', text: 'Откат Тест' });
    expect(t.events.length).toBe(before); // nothing published for incomplete work
  });
});
