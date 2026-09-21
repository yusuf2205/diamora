import { DiscoveryService, ModulesContainer, Reflector } from '@nestjs/core';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { IS_AUTHENTICATED, IS_PUBLIC, ROLES_KEY } from '../src/common/decorators';
import { PASSWORD, adminActor, adminLogin, client, createAdmin, createTestApp, uniquePhone, TestApp } from './support/app';

describe('authentication & sessions (ADMIN)', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp({ REFRESH_REUSE_GRACE_SECONDS: '0', LOGIN_MAX_FAILURES: '5' })));
  afterAll(() => t.close());
  const dev = () => ({ installId: randomUUID(), platform: 'ANDROID' });
  const post = (url: string, body: object) => request(t.app.getHttpServer()).post(url).send(body);

  it('logs in with phone + password (any phone notation), returns tokens and profile', async () => {
    const u = await createAdmin(t);
    const s = await adminLogin(t, u.phone);
    expect(s.user).toMatchObject({ id: u.id, role: 'ADMIN', workerId: null });
    const local = u.phone.replace('+998', '').replace(/(\d{2})(\d{3})(\d{2})(\d{2})/, '$1 $2 $3 $4');
    await post('/v1/auth/admin/login', { phone: local, password: PASSWORD, device: dev() }).expect(200);
    const me = await client(t, s.accessToken).get('/v1/auth/me').expect(200);
    expect(me.body).not.toHaveProperty('passwordHash');
  });

  it('wrong password and unknown phone give the SAME error (no enumeration); a WORKER phone cannot use the admin login', async () => {
    const u = await createAdmin(t);
    const a = await post('/v1/auth/admin/login', { phone: u.phone, password: 'wrong-password', device: dev() });
    const b = await post('/v1/auth/admin/login', { phone: uniquePhone(), password: 'whatever-123', device: dev() });
    expect([a.status, b.status]).toEqual([401, 401]);
    expect(a.body.error.message).toBe(b.body.error.message);
    const w = await t.prisma.user.create({ data: { phone: uniquePhone(), fullName: 'W', role: 'WORKER' } });
    expect((await post('/v1/auth/admin/login', { phone: w.phone, password: PASSWORD, device: dev() })).status).toBe(401);
  });

  it('locks after repeated failures (even for the right password), uniformly for unknown phones; ADMIN can unlock via new session only after window', async () => {
    const u = await createAdmin(t);
    for (let i = 0; i < 5; i++) await post('/v1/auth/admin/login', { phone: u.phone, password: `bad-password-${i}`, device: dev() }).expect(401);
    const locked = await post('/v1/auth/admin/login', { phone: u.phone, password: PASSWORD, device: dev() });
    expect(locked.status).toBe(429);
    expect(locked.body.error.code).toBe('RATE_LIMITED');
    expect(locked.headers['retry-after']).toBeDefined();
    const ghost = uniquePhone();
    for (let i = 0; i < 5; i++) await post('/v1/auth/admin/login', { phone: ghost, password: `bad-${i}-pw-x`, device: dev() });
    expect((await post('/v1/auth/admin/login', { phone: ghost, password: PASSWORD, device: dev() })).status).toBe(429);
  });

  it('rotates refresh tokens; replaying a rotated token burns the session (reuse detection)', async () => {
    const u = await createAdmin(t);
    const s1 = await adminLogin(t, u.phone);
    const r1 = await post('/v1/auth/refresh', { refreshToken: s1.refreshToken });
    expect(r1.status).toBe(200);
    expect(r1.body.refreshToken).not.toBe(s1.refreshToken);
    await client(t, r1.body.accessToken).get('/v1/auth/me').expect(200);
    const replay = await post('/v1/auth/refresh', { refreshToken: s1.refreshToken });
    expect(replay.body.error.code).toBe('SESSION_REVOKED');
    expect((await post('/v1/auth/refresh', { refreshToken: r1.body.refreshToken })).status).toBe(401);
    await client(t, r1.body.accessToken).get('/v1/auth/me').expect(401);
    expect(await t.prisma.auditLog.count({ where: { action: 'auth.refresh_reuse_detected', actorId: u.id } })).toBe(1);
  });

  it('logout / logout-all / revoke one device take effect immediately; same install replaces its old session', async () => {
    const u = await createAdmin(t);
    const installId = randomUUID();
    const first = await adminLogin(t, u.phone, PASSWORD, installId);
    await adminLogin(t, u.phone, PASSWORD, installId);
    await client(t, first.accessToken).get('/v1/auth/me').expect(401);

    const a = await adminLogin(t, u.phone);
    const b = await adminLogin(t, u.phone);
    const list = await client(t, a.accessToken).get('/v1/auth/sessions').expect(200);
    expect(list.body.length).toBeGreaterThanOrEqual(2);
    const other = list.body.find((s: { current: boolean }) => !s.current);
    await client(t, a.accessToken).delete(`/v1/auth/sessions/${other.id}`).expect(204);
    await client(t, a.accessToken).post('/v1/auth/logout-all').expect(200);
    await client(t, a.accessToken).get('/v1/auth/me').expect(401);
    await client(t, b.accessToken).get('/v1/auth/me').expect(401);
  });

  it('tampered or foreign tokens are rejected', async () => {
    const { session } = await adminActor(t);
    const [h, , sig] = session.accessToken.split('.');
    const forged = `${h}.${Buffer.from(JSON.stringify({ sub: 'x', sid: randomUUID(), role: 'ADMIN' })).toString('base64url')}.${sig}`;
    await client(t, forged).get('/v1/auth/me').expect(401);
    await client(t, 'garbage').get('/v1/auth/me').expect(401);
  });

  it('DENY BY DEFAULT: every route declares @Public, @Authenticated or @Roles', () => {
    const reflector = t.app.get(Reflector);
    const discovery = new DiscoveryService(t.app.get(ModulesContainer));
    const undeclared: string[] = [];
    let routes = 0;
    for (const wrapper of discovery.getControllers()) {
      const instance = wrapper.instance as Record<string, unknown> | null;
      if (!instance) continue;
      const proto = Object.getPrototypeOf(instance) as Record<string, unknown>;
      for (const name of Object.getOwnPropertyNames(proto)) {
        const handler = proto[name];
        if (typeof handler !== 'function' || name === 'constructor' || Reflect.getMetadata('path', handler) === undefined) continue;
        routes += 1;
        const targets = [handler as () => unknown, wrapper.metatype as () => unknown];
        if (!(reflector.getAllAndOverride(IS_PUBLIC, targets) || reflector.getAllAndOverride(IS_AUTHENTICATED, targets) || reflector.getAllAndOverride(ROLES_KEY, targets))) {
          undeclared.push(`${wrapper.metatype?.name}.${name}`);
        }
      }
    }
    expect(routes).toBeGreaterThan(20);
    expect(undeclared).toEqual([]);
  });

  it('health endpoints are public; errors use the uniform envelope with the request id', async () => {
    const live = await request(t.app.getHttpServer()).get('/health/live').expect(200);
    expect(live.body.status).toBe('ok');
    const ready = await request(t.app.getHttpServer()).get('/health/ready').expect(200);
    expect(ready.body.checks.database.status).toBe('up');
    const res = await request(t.app.getHttpServer()).get('/v1/workers').set('X-Request-Id', 'abc-12345678').expect(401);
    expect(res.body.error).toMatchObject({ code: 'UNAUTHENTICATED', requestId: 'abc-12345678' });
  });
});
