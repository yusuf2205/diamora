import type { RealtimeEnvelope } from '@yusmus/shared';
import { io, type Socket } from 'socket.io-client';
import { approveAndLoginWorker, client, createTestApp, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

const until = async (cond: () => boolean, ms = 3000) => {
  const end = Date.now() + ms;
  while (!cond() && Date.now() < end) await new Promise((r) => setTimeout(r, 25));
  return cond();
};
const TASHKENT = { latitude: 41.2995, longitude: 69.2401 };

describe('live location (D-030): every role reports its own position; reads are scoped exactly like worker data', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('any signed-in role reports its own position; the server ignores any userId/workerId the client sends', async () => {
    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, admin.api, reg.phone);

    const res = await worker.api.post('/v1/location', { ...TASHKENT, accuracy: 12, recordedAt: new Date().toISOString(), isBackground: true, userId: 'not-mine', workerId: 'also-not-mine' }).expect(200);
    expect(res.body.ok).toBe(true);
    const row = await t.prisma.userLiveLocation.findUniqueOrThrow({ where: { userId: worker.session.user.id } });
    expect(row.latitude).toBeCloseTo(TASHKENT.latitude, 3);
    // a worker's live report also refreshes her classic GPS field (used by M4's map) - never a foreign worker's
    const profile = await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: worker.workerId } });
    expect(Number(profile.latitude)).toBeCloseTo(TASHKENT.latitude, 3);
  });

  it('rejects nonsense coordinates; requires authentication', async () => {
    const admin = await superAdminActor(t);
    for (const bad of [{ latitude: 200, longitude: 10 }, { latitude: 10, longitude: -200 }]) {
      await admin.api.post('/v1/location', { ...bad, recordedAt: new Date().toISOString() }).expect(400);
    }
    await client(t).post('/v1/location', { ...TASHKENT, recordedAt: new Date().toISOString() }).expect(401);
  });

  it('reads are scoped: LIVE_LOCATION_VIEW_ALL sees everyone, _ASSIGNED only the manager\'s own workers + self, WORKER (no perm) is refused', async () => {
    const superAdmin = await superAdminActor(t);
    const mgrA = await staffActor(t, 'MANAGER', ['LIVE_LOCATION_VIEW_ASSIGNED']); // already default, explicit for clarity
    const mgrB = await staffActor(t, 'MANAGER');
    const regA = await registerViaBot(t);
    const regB = await registerViaBot(t);
    const wa = await approveAndLoginWorker(t, superAdmin.api, regA.phone);
    const wb = await approveAndLoginWorker(t, superAdmin.api, regB.phone);
    await superAdmin.api.post(`/v1/workers/${wa.workerId}/manager`, { managerId: mgrA.user.id }).expect(201);
    await superAdmin.api.post(`/v1/workers/${wb.workerId}/manager`, { managerId: mgrB.user.id }).expect(201);
    await wa.api.post('/v1/location', { ...TASHKENT, recordedAt: new Date().toISOString() }).expect(200);
    await wb.api.post('/v1/location', { latitude: 40.0, longitude: 65.0, recordedAt: new Date().toISOString() }).expect(200);
    await mgrA.api.post('/v1/location', { ...TASHKENT, recordedAt: new Date().toISOString() }).expect(200);

    const all = await superAdmin.api.get('/v1/locations').expect(200);
    const ids = (all.body.items as { worker: { id: string } | null }[]).map((i) => i.worker?.id).filter(Boolean);
    expect(ids).toEqual(expect.arrayContaining([wa.workerId, wb.workerId]));

    const scoped = await mgrA.api.get('/v1/locations').expect(200);
    const scopedWorkerIds = (scoped.body.items as { worker: { id: string } | null; userId: string }[]).map((i) => i.worker?.id).filter(Boolean);
    expect(scopedWorkerIds).toContain(wa.workerId);
    expect(scopedWorkerIds).not.toContain(wb.workerId);
    expect((scoped.body.items as { userId: string }[]).map((i) => i.userId)).toContain(mgrA.user.id); // sees her own position too

    await wa.api.get('/v1/locations').expect(403); // WORKER role: no LIVE_LOCATION_VIEW_* by default
  });

  it('a stale position is flagged, never presented as if it were current', async () => {
    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, admin.api, reg.phone);
    const old = new Date(Date.now() - 45 * 60_000).toISOString();
    await worker.api.post('/v1/location', { ...TASHKENT, recordedAt: old }).expect(200);
    const list = await admin.api.get('/v1/locations').expect(200);
    const row = (list.body.items as { worker: { id: string } | null; stale: boolean; ageSeconds: number }[]).find((i) => i.worker?.id === worker.workerId)!;
    expect(row.stale).toBe(true);
    expect(row.ageSeconds).toBeGreaterThan(15 * 60);
  });

  it('reporting a position publishes realtime events routed the same way as reads (LOCATION category + worker.location.updated)', async () => {
    const superAdmin = await superAdminActor(t);
    const mgrA = await staffActor(t, 'MANAGER', ['LIVE_LOCATION_VIEW_ASSIGNED']);
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, superAdmin.api, reg.phone);
    await superAdmin.api.post(`/v1/workers/${worker.workerId}/manager`, { managerId: mgrA.user.id }).expect(201);
    await t.app.listen(0, '127.0.0.1');
    const addr = t.app.getHttpServer().address();
    const url = `http://127.0.0.1:${typeof addr === 'object' && addr ? addr.port : 0}`;
    const connect = (token: string) => new Promise<{ socket: Socket; events: RealtimeEnvelope[] }>((resolve) => {
      const socket = io(url, { auth: { token }, transports: ['websocket'], reconnection: false });
      const events: RealtimeEnvelope[] = [];
      socket.on('event', (e: RealtimeEnvelope) => events.push(e));
      socket.on('ready', () => resolve({ socket, events }));
    });
    const mgr = await connect(mgrA.session.accessToken);
    try {
      await worker.api.post('/v1/location', { ...TASHKENT, recordedAt: new Date().toISOString() }).expect(200);
      expect(await until(() => mgr.events.some((e) => e.type === 'worker.location.updated'))).toBe(true);
      expect(await until(() => mgr.events.some((e) => e.type === 'user.location.updated'))).toBe(true);
    } finally {
      mgr.socket.close();
    }
  });
});
