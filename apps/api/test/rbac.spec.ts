import { randomUUID } from 'node:crypto';
import { io, type Socket } from 'socket.io-client';
import type { RealtimeEnvelope } from '@yusmus/shared';
import request from 'supertest';
import {
  adminActor, approveAndLoginWorker, client, createAdmin, createTestApp, PASSWORD, registerViaBot, staffActor, superAdminActor, TestApp,
} from './support/app';

const until = async (cond: () => boolean, ms = 3000) => {
  const end = Date.now() + ms;
  while (!cond() && Date.now() < end) await new Promise((r) => setTimeout(r, 25));
  return cond();
};
const phone = () => `+998${900_000_000 + Math.floor(Math.random() * 99_999_999)}`;

describe('RBAC (D-028): SUPER_ADMIN / ADMIN / MANAGER / WORKER, permissions, manager isolation', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());
  const dev = () => ({ installId: randomUUID(), platform: 'ANDROID' });
  const post = (url: string, body: object) => request(t.app.getHttpServer()).post(url).send(body);

  it('a fresh SUPER_ADMIN has every permission; ADMIN and MANAGER get the documented defaults; WORKER has none', async () => {
    const superAdmin = await superAdminActor(t);
    const admin = await staffActor(t, 'ADMIN');
    const manager = await staffActor(t, 'MANAGER');
    const s = await superAdmin.api.get(`/v1/users/${superAdmin.user.id}`).expect(200);
    expect(s.body.permissions).toEqual(expect.arrayContaining(['ROLE_ASSIGN', 'PERMISSION_MANAGE', 'PAY_RATE_MANAGE', 'SETTINGS_MANAGE', 'AUDIT_VIEW']));
    const a = await superAdmin.api.get(`/v1/users/${admin.user.id}`).expect(200);
    expect(a.body.permissions).toEqual(expect.arrayContaining(['WORKER_VIEW_ALL', 'WORKER_APPROVE', 'COLLATERAL_MANAGE', 'CATALOG_MANAGE']));
    expect(a.body.permissions).not.toEqual(expect.arrayContaining(['ROLE_ASSIGN', 'PAY_RATE_MANAGE']));
    const m = await superAdmin.api.get(`/v1/users/${manager.user.id}`).expect(200);
    expect(m.body.permissions).toEqual(expect.arrayContaining(['WORKER_VIEW_ASSIGNED', 'ASSIGNMENT_VIEW_ASSIGNED', 'FINANCE_VIEW_ASSIGNED']));
    // §6: collateral is visible to a MANAGER only "если permission разрешает" - never a default
    expect(m.body.permissions).not.toEqual(expect.arrayContaining(['WORKER_VIEW_ALL', 'PAY_RATE_MANAGE', 'COLLATERAL_VIEW']));
  });

  it('rank rule: USER_CREATE is not an ADMIN default (only SUPER_ADMIN creates staff out of the box); once granted, ADMIN is still capped by rank; MANAGER never gets it', async () => {
    const superAdmin = await superAdminActor(t);
    const bareAdmin = await staffActor(t, 'ADMIN');
    const admin = await staffActor(t, 'ADMIN', ['USER_CREATE']); // explicit grant, per D-028: user management defaults to SUPER_ADMIN only
    const manager = await staffActor(t, 'MANAGER');

    await bareAdmin.api.post('/v1/users', { phone: phone(), fullName: 'Nope', role: 'MANAGER', password: 'Typed-Pass-123' }).expect(403);
    await superAdmin.api.post('/v1/users', { phone: phone(), fullName: 'New Manager', role: 'MANAGER', password: 'Typed-Pass-123' }).expect(201);
    await admin.api.post('/v1/users', { phone: phone(), fullName: 'New Manager 2', role: 'MANAGER', password: 'Typed-Pass-123' }).expect(201); // ADMIN may create a strictly lower rank
    await admin.api.post('/v1/users', { phone: phone(), fullName: 'Rival Admin', role: 'ADMIN', password: 'Typed-Pass-123' }).expect(403); // same rank
    await admin.api.post('/v1/users', { phone: phone(), fullName: 'Boss', role: 'SUPER_ADMIN', password: 'Typed-Pass-123' }).expect(403); // higher rank
    await manager.api.post('/v1/users', { phone: phone(), fullName: 'Whoever', role: 'MANAGER', password: 'Typed-Pass-123' }).expect(403); // MANAGER has no USER_CREATE, not even grantable
  });

  it('SUPER_ADMIN can create an ADMIN outright; an ADMIN can never modify or suspend a SUPER_ADMIN', async () => {
    const superAdmin = await superAdminActor(t);
    const admin = await staffActor(t, 'ADMIN');
    const otherSuperAdmin = await superAdminActor(t);
    const created = await superAdmin.api.post('/v1/users', { phone: phone(), fullName: 'Brand New Admin', role: 'ADMIN', password: 'Typed-Pass-123' }).expect(201);
    expect(created.body.user.role).toBe('ADMIN');
    await admin.api.post(`/v1/users/${otherSuperAdmin.user.id}/status`, { status: 'SUSPENDED' }).expect(403); // strictly lower rank only
    await admin.api.put(`/v1/users/${otherSuperAdmin.user.id}/role`, { role: 'MANAGER' }).expect(403);
    await admin.api.patch(`/v1/users/${otherSuperAdmin.user.id}`, { fullName: 'Renamed' }).expect(403);
  });

  it('SUPER_ADMIN successfully changes a MANAGER to ADMIN: it takes effect, is audited, and the old session dies immediately', async () => {
    const superAdmin = await superAdminActor(t);
    const manager = await staffActor(t, 'MANAGER');
    const before = await client(t, manager.session.accessToken).get('/v1/auth/me').expect(200);
    expect(before.body.role).toBe('MANAGER');

    const res = await superAdmin.api.put(`/v1/users/${manager.user.id}/role`, { role: 'ADMIN' }).expect(200);
    expect(res.body.role).toBe('ADMIN');
    expect((await t.prisma.user.findUniqueOrThrow({ where: { id: manager.user.id } })).role).toBe('ADMIN');
    expect(await t.prisma.auditLog.findFirst({ where: { action: 'user.role_change', entityId: manager.user.id } })).toMatchObject({ before: { role: 'MANAGER' }, after: { role: 'ADMIN' } });
    // the OLD token is dead: a fresh login is required to pick up the new role, exactly like the mobile/web session model expects
    await client(t, manager.session.accessToken).get('/v1/auth/me').expect(401);
  });

  it('a client-supplied role in the login body is ignored: only the server-known role ever comes back', async () => {
    const u = await createAdmin(t);
    const res = await post('/v1/auth/admin/login', { phone: u.phone, password: PASSWORD, device: dev(), role: 'SUPER_ADMIN' } as never).expect(200);
    expect(res.body.user.role).toBe('ADMIN'); // the field the client tried to sneak in changes nothing
  });

  it('only SUPER_ADMIN assigns roles or manages permissions; nobody changes their own role/status/permissions', async () => {
    const superAdmin = await superAdminActor(t);
    const admin = await staffActor(t, 'ADMIN');
    await admin.api.put(`/v1/users/${admin.user.id}/role`, { role: 'SUPER_ADMIN' }).expect(403); // no ROLE_ASSIGN at all
    await superAdmin.api.put(`/v1/users/${superAdmin.user.id}/role`, { role: 'ADMIN' }).expect(403); // never yourself, even as SUPER_ADMIN
    await superAdmin.api.post(`/v1/users/${superAdmin.user.id}/status`, { status: 'SUSPENDED' }).expect(403);

    await superAdmin.api.put(`/v1/users/${admin.user.id}/permissions`, { grant: ['PAY_RATE_MANAGE'], revoke: [] }).expect(200);
    expect((await superAdmin.api.get(`/v1/users/${admin.user.id}`)).body.permissions).toContain('PAY_RATE_MANAGE');
    // a permission never grantable to ADMIN (SUPER_ADMIN-only) is rejected outright
    await superAdmin.api.put(`/v1/users/${admin.user.id}/permissions`, { grant: ['ROLE_ASSIGN'], revoke: [] }).expect(400);
    await admin.api.put(`/v1/users/${admin.user.id}/permissions`, { grant: [], revoke: ['WORKER_VIEW_ALL'] }).expect(403); // ADMIN has no PERMISSION_MANAGE
  });

  it('a SUPER_ADMIN may suspend another SUPER_ADMIN as long as at least one stays active', async () => {
    const a = await superAdminActor(t);
    const b = await superAdminActor(t);
    await a.api.post(`/v1/users/${b.user.id}/status`, { status: 'SUSPENDED' }).expect(200);
    expect(await t.prisma.user.count({ where: { role: 'SUPER_ADMIN', status: 'ACTIVE' } })).toBeGreaterThanOrEqual(1);
  });

  it('a deactivated user cannot sign in and loses every live session at once', async () => {
    const superAdmin = await superAdminActor(t);
    const admin = await staffActor(t, 'ADMIN');
    const api = client(t, admin.session.accessToken);
    await api.get('/v1/users').expect(200);
    await superAdmin.api.post(`/v1/users/${admin.user.id}/status`, { status: 'SUSPENDED', reason: 'test' }).expect(200);
    await api.get('/v1/users').expect(401); // the cached session is invalidated immediately (no 5 s wait)
    await request(t.app.getHttpServer()).post('/v1/auth/admin/login').send({ phone: admin.user.phone, password: 'Sup3r-Secret!', device: { installId: 'test-device-01', platform: 'ANDROID' } }).expect(403);
  });

  it('assigning a manager requires WORKER_ASSIGN_MANAGER (SUPER_ADMIN has it, plain ADMIN does not) and the target must be an active MANAGER', async () => {
    const superAdmin = await superAdminActor(t);
    const admin = await staffActor(t, 'ADMIN');
    const manager = await staffActor(t, 'MANAGER');
    const reg = await registerViaBot(t);
    const list = await superAdmin.api.get(`/v1/workers?q=${reg.phone.slice(-7)}`);
    const workerId: string = list.body.items[0].id;

    await admin.api.post(`/v1/workers/${workerId}/manager`, { managerId: manager.user.id }).expect(403);
    await superAdmin.api.post(`/v1/workers/${workerId}/manager`, { managerId: admin.user.id }).expect(409); // admin.user is not a MANAGER
    const assigned = await superAdmin.api.post(`/v1/workers/${workerId}/manager`, { managerId: manager.user.id }).expect(201);
    expect(assigned.body.manager).toMatchObject({ id: manager.user.id });
  });

  it('MANAGER default permissions see only assigned workers (never another manager\'s), 404 not 403 for the rest', async () => {
    const superAdmin = await superAdminActor(t);
    const mgrA = await staffActor(t, 'MANAGER');
    const mgrB = await staffActor(t, 'MANAGER');
    const regA = await registerViaBot(t);
    const regB = await registerViaBot(t);
    const wa = await approveAndLoginWorker(t, superAdmin.api, regA.phone);
    const wb = await approveAndLoginWorker(t, superAdmin.api, regB.phone);
    await superAdmin.api.post(`/v1/workers/${wa.workerId}/manager`, { managerId: mgrA.user.id }).expect(201);
    await superAdmin.api.post(`/v1/workers/${wb.workerId}/manager`, { managerId: mgrB.user.id }).expect(201);

    const listA = await mgrA.api.get('/v1/workers').expect(200);
    expect(listA.body.items.map((w: { id: string }) => w.id)).toContain(wa.workerId);
    expect(listA.body.items.map((w: { id: string }) => w.id)).not.toContain(wb.workerId);

    await mgrA.api.get(`/v1/workers/${wa.workerId}`).expect(200);
    await mgrA.api.get(`/v1/workers/${wb.workerId}`).expect(404); // not 403: existence of another manager's worker is not revealed either
  });

  it('collateral is invisible to a MANAGER by default ("если permission разрешает", §6); granting it still respects manager scope', async () => {
    const superAdmin = await superAdminActor(t);
    const mgrBare = await staffActor(t, 'MANAGER');
    const mgrGranted = await staffActor(t, 'MANAGER', ['COLLATERAL_VIEW', 'COLLATERAL_MANAGE']);
    const mgrOther = await staffActor(t, 'MANAGER', ['COLLATERAL_VIEW', 'COLLATERAL_MANAGE']);
    const regGranted = await registerViaBot(t);
    const regOther = await registerViaBot(t);
    const wGranted = await approveAndLoginWorker(t, superAdmin.api, regGranted.phone);
    const wOther = await approveAndLoginWorker(t, superAdmin.api, regOther.phone);
    await superAdmin.api.post(`/v1/workers/${wGranted.workerId}/manager`, { managerId: mgrGranted.user.id }).expect(201);
    await superAdmin.api.post(`/v1/workers/${wOther.workerId}/manager`, { managerId: mgrOther.user.id }).expect(201);

    await mgrBare.api.get('/v1/collaterals').expect(403); // no COLLATERAL_VIEW at all

    const own = await mgrGranted.api.get(`/v1/collaterals?workerId=${wGranted.workerId}`).expect(200);
    expect(own.body.items[0].worker.id).toBe(wGranted.workerId);
    const otherCollateralId: string = (await superAdmin.api.get(`/v1/collaterals?workerId=${wOther.workerId}`)).body.items[0].id;
    await mgrGranted.api.get(`/v1/collaterals/${otherCollateralId}`).expect(404); // has the permission, but not for THIS worker
    await mgrGranted.api.post(`/v1/collaterals/${otherCollateralId}/receive`, {}).expect(404);
  });

  it('realtime: a MANAGER only receives events about their own workers (default WORKER_VIEW_ASSIGNED), never another manager\'s', async () => {
    const superAdmin = await superAdminActor(t);
    const mgrA = await staffActor(t, 'MANAGER');
    const mgrB = await staffActor(t, 'MANAGER');
    await t.app.listen(0, '127.0.0.1');
    const addr = t.app.getHttpServer().address();
    const url = `http://127.0.0.1:${typeof addr === 'object' && addr ? addr.port : 0}`;
    const connect = (token: string) => new Promise<{ socket: Socket; events: RealtimeEnvelope[] }>((resolve) => {
      const socket = io(url, { auth: { token }, transports: ['websocket'], reconnection: false });
      const events: RealtimeEnvelope[] = [];
      socket.on('event', (e: RealtimeEnvelope) => events.push(e));
      socket.on('ready', () => resolve({ socket, events }));
    });
    const a = await connect(mgrA.session.accessToken);
    const b = await connect(mgrB.session.accessToken);
    try {
      const reg = await registerViaBot(t);
      const w = await approveAndLoginWorker(t, superAdmin.api, reg.phone);
      await superAdmin.api.post(`/v1/workers/${w.workerId}/manager`, { managerId: mgrA.user.id }).expect(201);

      expect(await until(() => a.events.some((e) => e.type === 'worker.manager_changed'))).toBe(true);
      await new Promise((r) => setTimeout(r, 150));
      expect(b.events.some((e) => e.type === 'worker.manager_changed')).toBe(false);
    } finally {
      a.socket.close();
      b.socket.close();
    }
  });

  it('a WORKER never reaches any staff-only route (/v1/users, /v1/managers, /v1/workers list) but keeps her own', async () => {
    const superAdmin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, superAdmin.api, reg.phone);
    await worker.api.get('/v1/users').expect(403);
    await worker.api.get('/v1/managers').expect(403);
    await worker.api.get('/v1/workers').expect(403);
    await worker.api.get('/v1/workers/me').expect(200); // her own route still works
  });

  it('an ADMIN created with a fixed password by bootstrap-style helper still goes through the same login/permission machinery', async () => {
    const admin = await adminActor(t); // legacy-style ADMIN actor (kept for the rest of the suite): still resolves effective permissions
    expect((await admin.api.get('/v1/auth/me')).body.permissions).toEqual(expect.arrayContaining(['WORKER_VIEW_ALL']));
  });
});
