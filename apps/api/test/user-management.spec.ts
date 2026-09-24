import type { RealtimeEnvelope } from '@yusmus/shared';
import { io, type Socket } from 'socket.io-client';
import { approveAndLoginWorker, createTestApp, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

const until = async (fn: () => boolean, ms = 3000) => {
  const end = Date.now() + ms;
  while (Date.now() < end) { if (fn()) return true; await new Promise((r) => setTimeout(r, 25)); }
  return fn();
};

describe('user management: manager reassignment, archive/restore — every channel follows the server', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('reassigning a worker moves REST, map, QR and realtime access from the old manager to the new one at once', async () => {
    const admin = await superAdminActor(t);
    const oldMgr = await staffActor(t, 'MANAGER');
    const newMgr = await staffActor(t, 'MANAGER');
    const reg = await registerViaBot(t);
    const w = await approveAndLoginWorker(t, admin.api, reg.phone);
    await admin.api.post(`/v1/workers/${w.workerId}/manager`, { managerId: oldMgr.user.id }).expect(201);
    await w.api.post('/v1/location', { latitude: 41.3, longitude: 69.28, recordedAt: new Date().toISOString() }).expect(200);
    const qr = (await admin.api.get(`/v1/workers/${w.workerId}`).expect(200)).body.qrCode as string;
    const mapIds = async (api: typeof admin.api) =>
      ((await api.get('/v1/locations').expect(200)).body.items as { worker: { id: string } | null }[]).map((i) => i.worker?.id);

    await oldMgr.api.get(`/v1/workers/${w.workerId}`).expect(200);
    await oldMgr.api.get(`/v1/qr/${qr}`).expect(200);
    expect(await mapIds(oldMgr.api)).toContain(w.workerId);

    await t.app.listen(0, '127.0.0.1');
    const addr = t.app.getHttpServer().address();
    const url = `http://127.0.0.1:${typeof addr === 'object' && addr ? addr.port : 0}`;
    const connect = (token: string) => new Promise<{ socket: Socket; events: RealtimeEnvelope[] }>((resolve) => {
      const socket = io(url, { auth: { token }, transports: ['websocket'], reconnection: false });
      const events: RealtimeEnvelope[] = [];
      socket.on('event', (e: RealtimeEnvelope) => events.push(e));
      socket.on('ready', () => resolve({ socket, events }));
    });
    const o = await connect(oldMgr.session.accessToken);
    const n = await connect(newMgr.session.accessToken);
    try {
      await admin.api.post(`/v1/workers/${w.workerId}/manager`, { managerId: newMgr.user.id }).expect(201);
      // both hear the reassignment: the old list must drop her, the new one must show her
      expect(await until(() => o.events.some((e) => e.type === 'worker.manager_changed'))).toBe(true);
      expect(await until(() => n.events.some((e) => e.type === 'worker.manager_changed'))).toBe(true);

      await oldMgr.api.get(`/v1/workers/${w.workerId}`).expect(404);
      await oldMgr.api.get(`/v1/qr/${qr}`).expect(404);
      expect(await mapIds(oldMgr.api)).not.toContain(w.workerId);
      await newMgr.api.get(`/v1/workers/${w.workerId}`).expect(200);
      await newMgr.api.get(`/v1/qr/${qr}`).expect(200);
      expect(await mapIds(newMgr.api)).toContain(w.workerId);

      // from now on her events reach only the new manager
      o.events.length = 0;
      await w.api.post('/v1/location', { latitude: 41.31, longitude: 69.29, recordedAt: new Date().toISOString() }).expect(200);
      expect(await until(() => n.events.some((e) => e.type === 'worker.location.updated' || e.type === 'user.location.updated'))).toBe(true);
      await new Promise((r) => setTimeout(r, 150));
      expect(o.events.some((e) => (e.data as { workerId?: string }).workerId === w.workerId)).toBe(false);

      const audit = await t.prisma.auditLog.findFirst({ where: { action: 'worker.assign_manager', entityId: w.workerId }, orderBy: { createdAt: 'desc' } });
      expect(audit?.after).toMatchObject({ managerId: newMgr.user.id });
    } finally {
      o.socket.close();
      n.socket.close();
    }
  });

  it('a MANAGER cannot change roles or reassign workers; an ADMIN cannot promote anybody to SUPER_ADMIN', async () => {
    const admin = await staffActor(t, 'ADMIN', ['USER_UPDATE']);
    const mgr = await staffActor(t, 'MANAGER');
    const other = await staffActor(t, 'MANAGER');
    await mgr.api.put(`/v1/users/${other.user.id}/role`, { role: 'ADMIN' }).expect(403);
    await mgr.api.put(`/v1/users/${mgr.user.id}/role`, { role: 'SUPER_ADMIN' }).expect(403);
    await admin.api.put(`/v1/users/${other.user.id}/role`, { role: 'SUPER_ADMIN' }).expect(403);
    await admin.api.put(`/v1/users/${admin.user.id}/role`, { role: 'SUPER_ADMIN' }).expect(403);
    const reg = await registerViaBot(t);
    const superAdmin = await superAdminActor(t);
    const w = await approveAndLoginWorker(t, superAdmin.api, reg.phone);
    await mgr.api.post(`/v1/workers/${w.workerId}/manager`, { managerId: mgr.user.id }).expect(403);
    expect((await t.prisma.user.findUniqueOrThrow({ where: { id: other.user.id } })).role).toBe('MANAGER');
  });

  it('an archived worker gets no new assignment and cannot sign in; «Восстановить» brings her back with history intact', async () => {
    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const { workerId } = await approveAndLoginWorker(t, admin.api, reg.phone);
    const tape = await admin.api.post('/v1/admin/materials', { name: `ArchTape ${reg.tgId}`, unit: 'METER', minStock: '0' }).expect(201);
    await admin.api.post('/v1/admin/stock/receipt', { materialId: tape.body.id, quantity: '100', comment: 'setup' }).expect(201);
    const kit = await admin.api.post('/v1/admin/kits', { name: `ArchKit ${reg.tgId}`, ribbonMeters: 9, items: [{ materialId: tape.body.id, requiredQuantity: '9' }] }).expect(201);
    const color = await admin.api.post('/v1/admin/colors', { name: `ArchColor ${reg.tgId}` }).expect(201);
    const item = await admin.api.post('/v1/admin/catalog', { name: `ArchModel ${reg.tgId}` }).expect(201);
    const withVariant = await admin.api.post(`/v1/admin/catalog/${item.body.id}/variants`, { colorId: color.body.id }).expect(201);
    const variant = (withVariant.body.variants as { id: string; color: { id: string } }[]).find((v) => v.color.id === color.body.id)!;
    const body = { workerId, productModelId: item.body.id, productVariantId: variant.id, colorId: color.body.id, materialKitTemplateId: kit.body.id, kitCount: 1 };
    await admin.api.post('/v1/admin/assignments', body).expect(201); // history to keep

    await admin.api.patch(`/v1/workers/${workerId}`, { status: 'ARCHIVED' }).expect(200);
    const refused = await admin.api.post('/v1/admin/assignments', body).expect(409);
    expect(refused.body.error.message).toMatch(/not active/i);
    const archivedList = await admin.api.get('/v1/workers?status=ACTIVE&limit=100').expect(200);
    expect((archivedList.body.items as { id: string }[]).map((i) => i.id)).not.toContain(workerId);

    await admin.api.patch(`/v1/workers/${workerId}`, { status: 'ACTIVE' }).expect(200);
    expect((await t.prisma.user.findFirstOrThrow({ where: { workerProfile: { id: workerId } } })).status).toBe('ACTIVE');
    expect(await t.prisma.workAssignment.count({ where: { workerId } })).toBe(1);
    await admin.api.post('/v1/admin/assignments', body).expect(201);
  });
});
