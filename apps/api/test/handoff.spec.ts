import type { RealtimeEnvelope } from '@yusmus/shared';
import { io, type Socket } from 'socket.io-client';
import { approveAndLoginWorker, handOver, registerViaBot, staffActor, superAdminActor, TestApp, createTestApp } from './support/app';

/** One active worker + a 9 m kit (tape + beads) + a catalog variant, all fresh per test (see assignments.spec.ts). */
async function setup(t: TestApp) {
  const admin = await superAdminActor(t);
  const reg = await registerViaBot(t);
  const { workerId, api: workerApi, session } = await approveAndLoginWorker(t, admin.api, reg.phone);
  const tape = await admin.api.post('/v1/admin/materials', { name: `HTape ${reg.tgId}`, unit: 'METER', minStock: '0' }).expect(201);
  const bead = await admin.api.post('/v1/admin/materials', { name: `HBead ${reg.tgId}`, unit: 'GRAM', minStock: '0' }).expect(201);
  await admin.api.post('/v1/admin/stock/receipt', { materialId: tape.body.id, quantity: '100', comment: 'setup' }).expect(201);
  await admin.api.post('/v1/admin/stock/receipt', { materialId: bead.body.id, quantity: '1000', comment: 'setup' }).expect(201);
  const kit = await admin.api.post('/v1/admin/kits', {
    name: `HKit ${reg.tgId}`, ribbonMeters: 9, items: [{ materialId: tape.body.id, requiredQuantity: '9' }, { materialId: bead.body.id, requiredQuantity: '40' }],
  }).expect(201);
  const color = await admin.api.post('/v1/admin/colors', { name: `HColor ${reg.tgId}` }).expect(201);
  const item = await admin.api.post('/v1/admin/catalog', { name: `HModel ${reg.tgId}` }).expect(201);
  const withVariant = await admin.api.post(`/v1/admin/catalog/${item.body.id}/variants`, { colorId: color.body.id }).expect(201);
  const variant = (withVariant.body.variants as { id: string; color: { id: string } }[]).find((v) => v.color.id === color.body.id)!;
  const created = await admin.api.post('/v1/admin/assignments', {
    workerId, productModelId: item.body.id, productVariantId: variant.id, colorId: color.body.id, materialKitTemplateId: kit.body.id, kitCount: 2,
  }).expect(201);
  return { admin, workerId, workerApi, workerToken: session.accessToken, tape: tape.body, bead: bead.body, id: created.body.id as string, qr: created.body.qrCode as string };
}

const held = (t: TestApp, workerId: string) => t.prisma.workerMaterialBalance.findMany({ where: { workerId } });
const movementsOf = (t: TestApp, assignmentId: string, type: 'ISSUE_TO_WORKER' | 'ISSUE_TO_KIT' | 'CONSUMPTION') => t.prisma.stockMovement.count({ where: { assignmentId, type } });

describe('two-sided QR handoff (Phase 5): staff scans first, the worker scans and personally confirms', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('assigned ≠ received: the worker sees the waiting work with its expected pay, but cannot progress it and holds nothing', async () => {
    const f = await setup(t);
    const cur = await f.workerApi.get('/v1/work/current').expect(200);
    expect(cur.body.status).toBe('READY_TO_DELIVER');
    expect(cur.body.handoff).toBeNull();
    const rate = await f.admin.api.get('/v1/settings/pay-rate').expect(200);
    expect(cur.body.expectedPayment).toBe(String(BigInt(rate.body.ratePerKit) * 2n)); // 18 m = 2 kits
    await f.workerApi.post(`/v1/work/${f.id}/progress`, { reportedMeters: '1' }).expect(409);
    await f.workerApi.post(`/v1/work/${f.id}/ready`, { readyMeters: '1' }).expect(409);
    expect(await held(t, f.workerId)).toEqual([]);
    expect(await movementsOf(t, f.id, 'ISSUE_TO_KIT')).toBe(2); // prepared: off the shelf, into the kit
    expect(await movementsOf(t, f.id, 'ISSUE_TO_WORKER')).toBe(0);
  });

  it('worker before staff is refused (HANDOFF_NOT_STARTED); an invalid QR is a clean 404', async () => {
    const f = await setup(t);
    const early = await f.workerApi.post('/v1/work/handoff/scan', { code: f.qr }).expect(409);
    expect(early.body.error.code).toBe('HANDOFF_NOT_STARTED');
    await f.workerApi.post('/v1/work/handoff/scan', { code: 'YQ1.ZZZZZZZZZZZZ' }).expect(404);
    await f.workerApi.post('/v1/work/handoff/scan', { code: 'hello' }).expect(404);
  });

  it('full handoff: staff starts -> worker scans -> worker confirms -> custody + delivery + IN_PROGRESS + receipt facts + audit', async () => {
    const f = await setup(t);
    const started = await f.admin.api.post(`/v1/admin/assignments/${f.id}/handoff`, {}).expect(200);
    expect(started.body.status).toBe('READY_TO_DELIVER'); // nothing moved yet
    expect(started.body.handoff.status).toBe('AWAITING_WORKER');
    expect(started.body.handoff.staff.id).toBe(f.admin.user.id);
    expect(await held(t, f.workerId)).toEqual([]);

    const scan = await f.workerApi.post('/v1/work/handoff/scan', { code: f.qr.toLowerCase() }).expect(200);
    expect(scan.body.state).toBe('AWAITING_WORKER');
    expect(scan.body.assignment.plannedMeters).toBe(18);
    expect(scan.body.assignment.kitCount).toBe(2);
    expect(scan.body.assignment.materials).toHaveLength(2);
    expect(await held(t, f.workerId)).toEqual([]); // scanning alone moves nothing

    const done = await f.workerApi.post(`/v1/work/handoff/${scan.body.handoffId}/confirm`, { latitude: 41.3, longitude: 69.24, accuracyM: 12 }).expect(200);
    expect(done.body.status).toBe('IN_PROGRESS');
    expect(done.body.handoff.status).toBe('CONFIRMED');
    expect(done.body.handoff.workerScannedAt).toBeTruthy();
    expect(done.body.handoff.workerAcceptedAt).toBeTruthy();
    expect(done.body.handoff.hasLocation).toBe(true);
    expect(done.body.handoffTimeline.map((e: { kind: string }) => e.kind)).toEqual(['HANDOFF_STARTED', 'WORKER_SCANNED', 'WORKER_CONFIRMED']);
    expect(done.body.deliveries.find((d: { type: string }) => d.type === 'DELIVERY_TO_WORKER').status).toBe('COMPLETED');

    const h = await t.prisma.assignmentHandoff.findFirstOrThrow({ where: { assignmentId: f.id } });
    expect(h).toMatchObject({ staffUserId: f.admin.user.id, workerId: f.workerId, kitCount: 2, latitude: 41.3, accuracyM: 12 });
    expect((h.materialSnapshot as unknown[]).length).toBe(2);
    const bal = await held(t, f.workerId);
    expect(bal.find((b) => b.materialId === f.tape.id)!.quantity.toString()).toBe('18');
    expect(bal.find((b) => b.materialId === f.bead.id)!.quantity.toString()).toBe('80');
    // the warehouse was charged ONCE, at preparation - the handoff moves custody, not stock
    const stock = await f.admin.api.get('/v1/admin/stock/balances').expect(200);
    expect(stock.body.items.find((b: { materialId: string }) => b.materialId === f.tape.id).quantity).toBe(100 - 18);

    const actions = (await t.prisma.auditLog.findMany({ where: { entityId: f.id }, select: { action: true } })).map((a) => a.action);
    expect(actions).toEqual(expect.arrayContaining(['handoff.started', 'handoff.worker_scanned', 'handoff.confirmed']));

    // after pickup the materials she held became the finished work: her balance goes back to zero
    await f.workerApi.post(`/v1/work/${f.id}/ready`, { readyMeters: '18' }).expect(200);
    await f.admin.api.post(`/v1/admin/assignments/${f.id}/pickup`, {}).expect(200);
    expect((await held(t, f.workerId)).every((b) => b.quantity.isZero())).toBe(true);
    expect(await movementsOf(t, f.id, 'CONSUMPTION')).toBe(2);
  });

  it('duplicate confirm is a replay, and a concurrent double-tap creates exactly ONE receipt', async () => {
    const f = await setup(t);
    await f.admin.api.post(`/v1/admin/assignments/${f.id}/handoff`, {}).expect(200);
    await f.admin.api.post(`/v1/admin/assignments/${f.id}/handoff`, {}).expect(200); // a second staff scan = the same handoff
    expect(await t.prisma.assignmentHandoff.count({ where: { assignmentId: f.id } })).toBe(1);
    const scan = await f.workerApi.post('/v1/work/handoff/scan', { code: f.qr }).expect(200);
    const url = `/v1/work/handoff/${scan.body.handoffId}/confirm`;
    const results = await Promise.all([f.workerApi.post(url, {}), f.workerApi.post(url, {}), f.workerApi.post(url, {})]);
    expect(results.map((r) => r.status)).toEqual([200, 200, 200]);
    await f.workerApi.post(url, {}).expect(200); // later replay

    expect(await movementsOf(t, f.id, 'ISSUE_TO_WORKER')).toBe(2); // one per material, never doubled
    expect(await t.prisma.assignmentHandoff.count({ where: { assignmentId: f.id, status: 'CONFIRMED' } })).toBe(1);
    expect(await t.prisma.delivery.count({ where: { assignmentId: f.id, type: 'DELIVERY_TO_WORKER', status: 'COMPLETED' } })).toBe(1);
    expect(await t.prisma.workAssignmentStatusHistory.count({ where: { assignmentId: f.id, toStatus: 'IN_PROGRESS' } })).toBe(1);
    expect((await held(t, f.workerId)).find((b) => b.materialId === f.tape.id)!.quantity.toString()).toBe('18');
    // a rescan after confirmation just says "already received"
    const again = await f.workerApi.post('/v1/work/handoff/scan', { code: f.qr }).expect(200);
    expect(again.body.state).toBe('CONFIRMED');
  });

  it('foreign worker: gets FOREIGN_KIT and not a byte of the assignment; cannot confirm someone else\'s handoff', async () => {
    const f = await setup(t);
    const other = await setup(t);
    await f.admin.api.post(`/v1/admin/assignments/${f.id}/handoff`, {}).expect(200);
    const res = await other.workerApi.post('/v1/work/handoff/scan', { code: f.qr }).expect(403);
    expect(res.body.error.code).toBe('FOREIGN_KIT');
    expect(JSON.stringify(res.body)).not.toContain(f.id);
    const scan = await f.workerApi.post('/v1/work/handoff/scan', { code: f.qr }).expect(200);
    await other.workerApi.post(`/v1/work/handoff/${scan.body.handoffId}/confirm`, {}).expect(404);
    expect(await held(t, other.workerId)).toEqual([]);
    expect(await held(t, f.workerId)).toEqual([]);
  });

  it('manager scope: own worker may be handed over, a foreign manager gets 404; staff cannot use worker endpoints', async () => {
    const f = await setup(t);
    const own = await staffActor(t, 'MANAGER', ['ASSIGNMENT_VIEW_ASSIGNED']);
    const foreign = await staffActor(t, 'MANAGER', ['ASSIGNMENT_VIEW_ASSIGNED']);
    await f.admin.api.post(`/v1/workers/${f.workerId}/manager`, { managerId: own.user.id }).expect(201);
    await foreign.api.post(`/v1/admin/assignments/${f.id}/handoff`, {}).expect(404);
    const started = await own.api.post(`/v1/admin/assignments/${f.id}/handoff`, {}).expect(200);
    expect(started.body.handoff.staff.id).toBe(own.user.id);
    await own.api.post('/v1/work/handoff/scan', { code: f.qr }).expect(403);
  });

  it('«Есть проблема»: nothing moves, work stays waiting, staff can start again and the worker then confirms', async () => {
    const f = await setup(t);
    await f.admin.api.post(`/v1/admin/assignments/${f.id}/handoff`, {}).expect(200);
    const scan = await f.workerApi.post('/v1/work/handoff/scan', { code: f.qr }).expect(200);
    const p = await f.workerApi.post(`/v1/work/handoff/${scan.body.handoffId}/problem`, { reason: 'WRONG_COLOR', comment: 'розовый вместо синего' }).expect(200);
    expect(p.body.status).toBe('READY_TO_DELIVER');
    expect(p.body.handoff).toMatchObject({ status: 'PROBLEM', problemReason: 'WRONG_COLOR' });
    expect(await held(t, f.workerId)).toEqual([]);
    await f.workerApi.post(`/v1/work/handoff/${scan.body.handoffId}/confirm`, {}).expect(409); // closed handoff
    await f.workerApi.post('/v1/work/handoff/scan', { code: f.qr }).expect(409); // needs a new staff scan
    await f.workerApi.post(`/v1/work/handoff/${scan.body.handoffId}/problem`, { reason: 'NOPE' }).expect(400);

    const done = await handOver(f.admin.api, f.workerApi, f.id);
    expect(done.body.status).toBe('IN_PROGRESS');
    expect(done.body.handoffTimeline.map((e: { kind: string }) => e.kind)).toContain('WORKER_PROBLEM');
  });

  it('expired handoff is refused; staff simply scans again. Disabled worker and cancelled work are refused', async () => {
    const f = await setup(t);
    await f.admin.api.post(`/v1/admin/assignments/${f.id}/handoff`, {}).expect(200);
    const scan = await f.workerApi.post('/v1/work/handoff/scan', { code: f.qr }).expect(200);
    await t.prisma.assignmentHandoff.update({ where: { id: scan.body.handoffId }, data: { expiresAt: new Date(Date.now() - 1000) } });
    const late = await f.workerApi.post(`/v1/work/handoff/${scan.body.handoffId}/confirm`, {}).expect(409);
    expect(late.body.error.code).toBe('HANDOFF_EXPIRED');
    expect((await f.workerApi.post('/v1/work/handoff/scan', { code: f.qr }).expect(409)).body.error.code).toBe('HANDOFF_EXPIRED');
    const restarted = await f.admin.api.post(`/v1/admin/assignments/${f.id}/handoff`, {}).expect(200);
    expect(restarted.body.handoff.id).not.toBe(scan.body.handoffId);
    expect(restarted.body.handoff.status).toBe('AWAITING_WORKER');

    // a paused worker can neither be handed work nor confirm it
    const scan2 = await f.workerApi.post('/v1/work/handoff/scan', { code: f.qr }).expect(200);
    await t.prisma.workerProfile.update({ where: { id: f.workerId }, data: { status: 'PAUSED' } });
    const denied = await f.workerApi.post(`/v1/work/handoff/${scan2.body.handoffId}/confirm`, {});
    expect([401, 403]).toContain(denied.status);
    expect(await held(t, f.workerId)).toEqual([]);

    const g = await setup(t);
    await t.prisma.workAssignment.update({ where: { id: g.id }, data: { status: 'CANCELLED' } });
    await g.admin.api.post(`/v1/admin/assignments/${g.id}/handoff`, {}).expect(409);
    await g.workerApi.post('/v1/work/handoff/scan', { code: g.qr }).expect(409);
  });

  it('old apps: POST /deliver only STARTS the handoff, it can never finish a delivery on its own', async () => {
    const f = await setup(t);
    const res = await f.admin.api.post(`/v1/admin/assignments/${f.id}/deliver`, {}).expect(200);
    expect(res.body.status).toBe('READY_TO_DELIVER');
    expect(res.body.handoff.status).toBe('AWAITING_WORKER');
    expect(await held(t, f.workerId)).toEqual([]);
  });

  it('realtime: the worker is told a handoff started, her manager sees the confirmation, a foreign manager sees nothing', async () => {
    await t.app.listen(0, '127.0.0.1');
    const addr = t.app.getHttpServer().address();
    const url = `http://127.0.0.1:${typeof addr === 'object' && addr ? addr.port : 0}`;
    const connect = (token: string) => new Promise<{ socket: Socket; events: RealtimeEnvelope[] }>((resolve) => {
      const socket = io(url, { auth: { token }, transports: ['websocket'], reconnection: false });
      const events: RealtimeEnvelope[] = [];
      socket.on('event', (e: RealtimeEnvelope) => events.push(e));
      socket.on('ready', () => resolve({ socket, events }));
    });
    const until = async (cond: () => boolean, ms = 3000) => {
      const end = Date.now() + ms;
      while (!cond() && Date.now() < end) await new Promise((r) => setTimeout(r, 25));
      return cond();
    };

    const f = await setup(t);
    const own = await staffActor(t, 'MANAGER', ['ASSIGNMENT_VIEW_ASSIGNED']);
    const foreign = await staffActor(t, 'MANAGER', ['ASSIGNMENT_VIEW_ASSIGNED']);
    await f.admin.api.post(`/v1/workers/${f.workerId}/manager`, { managerId: own.user.id }).expect(201);
    const w = await connect(f.workerToken);
    const m = await connect(own.session.accessToken);
    const x = await connect(foreign.session.accessToken);
    try {
      await own.api.post(`/v1/admin/assignments/${f.id}/handoff`, {}).expect(200);
      expect(await until(() => w.events.some((e) => e.type === 'handoff.started'))).toBe(true);
      const scan = await f.workerApi.post('/v1/work/handoff/scan', { code: f.qr }).expect(200);
      await f.workerApi.post(`/v1/work/handoff/${scan.body.handoffId}/confirm`, {}).expect(200);
      expect(await until(() => m.events.some((e) => e.type === 'handoff.confirmed'))).toBe(true);
      expect(m.events.some((e) => e.type === 'handoff.scanned')).toBe(true);
      await new Promise((r) => setTimeout(r, 200));
      expect(x.events.filter((e) => e.type.startsWith('handoff.'))).toEqual([]);
    } finally {
      [w, m, x].forEach((c) => c.socket.close());
    }
  });
});
