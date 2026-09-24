import { adminLogin, approveAndLoginWorker, client, createTestApp, PASSWORD, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

describe('owner privileges: company contact, passwords, whose location is visible', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('company phone + Telegram save (was a 500: the audit row used a non-UUID id) and are audited', async () => {
    const admin = await superAdminActor(t);
    const res = await admin.api.put('/v1/settings/company-contact', { phone: '+998 90 123 45 67', telegramUsername: '@diamoraa_uz' }).expect(200);
    expect(res.body).toMatchObject({ phone: '+998901234567', telegramUsername: 'diamoraa_uz', telegramUrl: 'https://t.me/diamoraa_uz' });
    const again = await admin.api.get('/v1/settings/company-contact').expect(200);
    expect(again.body.phone).toBe('+998901234567');
    expect(await t.prisma.auditLog.count({ where: { action: 'settings.company_contact' } })).toBeGreaterThanOrEqual(1);
    await admin.api.put('/v1/settings/company-contact', { phone: null, telegramUsername: null }).expect(200); // leave no residue
  });

  it('anyone with a password changes their own: wrong current = 400 (never a 401 sign-out), other sessions end, this one stays', async () => {
    const mgr = await staffActor(t, 'MANAGER');
    const phone = (await t.prisma.user.findUniqueOrThrow({ where: { id: mgr.user.id } })).phone;
    const second = await adminLogin(t, phone); // the same person on another device
    const wrong = await mgr.api.post('/v1/auth/change-password', { currentPassword: 'nope-nope', newPassword: 'Brand-New-Pass-1' }).expect(400);
    expect(wrong.body.error.code).toBe('WRONG_PASSWORD');
    await mgr.api.post('/v1/auth/change-password', { currentPassword: PASSWORD, newPassword: 'short' }).expect(400);

    const ok = await mgr.api.post('/v1/auth/change-password', { currentPassword: PASSWORD, newPassword: 'Brand-New-Pass-1' }).expect(200);
    expect(ok.body.otherSessionsSignedOut).toBeGreaterThanOrEqual(1);
    await mgr.api.get('/v1/auth/me').expect(200); // this device keeps working
    await client(t, second.accessToken).get('/v1/auth/me').expect(401); // the other device was signed out
    await adminLogin(t, phone, 'Brand-New-Pass-1');
    expect(await t.prisma.auditLog.count({ where: { action: 'user.password_change', entityId: mgr.user.id } })).toBe(1);
  });

  it('setting a password: always the typed one; SUPER_ADMIN may, an ADMIN only once granted PASSWORD_SET', async () => {
    const owner = await superAdminActor(t);
    const admin = await staffActor(t, 'ADMIN', ['USER_UPDATE']);
    const trusted = await staffActor(t, 'ADMIN', ['PASSWORD_SET']);
    const mgr = await staffActor(t, 'MANAGER');
    const phone = (await t.prisma.user.findUniqueOrThrow({ where: { id: mgr.user.id } })).phone;

    await admin.api.post(`/v1/users/${mgr.user.id}/reset-password`, { password: 'Chosen-By-Admin-1' }).expect(403); // not granted
    await owner.api.post(`/v1/users/${mgr.user.id}/reset-password`, {}).expect(400); // the program never invents one
    await trusted.api.post(`/v1/users/${mgr.user.id}/reset-password`, { password: 'Chosen-By-Admin-2' }).expect(200);
    await trusted.api.post(`/v1/users/${owner.user.id}/reset-password`, { password: 'Owner-Takeover-1' }).expect(403); // rank rule
    await adminLogin(t, phone, 'Chosen-By-Admin-2');

    const set = await owner.api.post(`/v1/users/${mgr.user.id}/reset-password`, { password: 'Chosen-By-Owner-1' }).expect(200);
    expect(set.body).toEqual({ passwordSet: true });
    await mgr.api.get('/v1/auth/me').expect(401); // every session of theirs ended
    await adminLogin(t, phone, 'Chosen-By-Owner-1');
  });

  it('a hidden person vanishes from everyone else\'s map; the SUPER_ADMIN still sees them (flagged) and alone may toggle it', async () => {
    const owner = await superAdminActor(t);
    const admin = await staffActor(t, 'ADMIN');
    const reg = await registerViaBot(t);
    const w = await approveAndLoginWorker(t, owner.api, reg.phone);
    const wUser = (await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.workerId } })).userId!;
    await w.api.post('/v1/location', { latitude: 41.3, longitude: 69.28, recordedAt: new Date().toISOString() }).expect(200);
    const ids = async (api: typeof owner.api) => ((await api.get('/v1/locations').expect(200)).body.items as { userId: string; hidden: boolean }[]);

    expect((await ids(admin.api)).map((i) => i.userId)).toContain(wUser);
    await admin.api.put(`/v1/users/${wUser}/location-visibility`, { hidden: true }).expect(403);

    await owner.api.put(`/v1/users/${wUser}/location-visibility`, { hidden: true }).expect(200);
    expect((await ids(admin.api)).map((i) => i.userId)).not.toContain(wUser);
    expect((await ids(owner.api)).find((i) => i.userId === wUser)?.hidden).toBe(true);
    expect(await t.prisma.auditLog.count({ where: { action: 'user.location_visibility', entityId: wUser } })).toBe(1);

    await owner.api.put(`/v1/users/${wUser}/location-visibility`, { hidden: false }).expect(200);
    expect((await ids(admin.api)).map((i) => i.userId)).toContain(wUser);
  });
});
