import { generateKeyPairSync, createVerify } from 'node:crypto';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { AppNotifier } from '../src/notifications/app-notifier';
import { createTestApp, staffActor, TestApp } from './support/app';

/** Instant notifications (Firebase Cloud Messaging HTTP v1): device tokens, a signed service-account JWT, data-only push. */
describe('push notifications', () => {
  let t: TestApp;
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const dir = mkdtempSync(join(tmpdir(), 'fcm-'));
  const file = join(dir, 'firebase-admin.json');
  writeFileSync(file, JSON.stringify({
    type: 'service_account', project_id: 'diamoraa-test', client_email: 'push@diamoraa-test.iam.gserviceaccount.com',
    private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }), token_uri: 'https://oauth2.googleapis.com/token',
  }));
  const calls: { url: string; body: string; auth?: string }[] = [];
  const realFetch = global.fetch;

  beforeAll(async () => {
    t = await createTestApp({ FIREBASE_CREDENTIALS_FILE: file });
    global.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
      const url = String(input);
      if (!url.startsWith('https://')) return realFetch(input, init); // supertest talks to the local app
      calls.push({ url, body: String(init?.body ?? ''), auth: (init?.headers as Record<string, string> | undefined)?.Authorization });
      if (url.includes('oauth2')) return new Response(JSON.stringify({ access_token: 'ya29.test', expires_in: 3600 }), { status: 200 });
      if (init?.body && String(init.body).includes('dead-token')) return new Response('{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}', { status: 404 });
      return new Response('{"name":"projects/diamoraa-test/messages/1"}', { status: 200 });
    }) as typeof fetch;
  });
  afterAll(async () => { global.fetch = realFetch; await t.close(); });

  it('a signed-in phone registers its token; a notice is pushed to it (data-only, with the notice id); a dead token is dropped', async () => {
    const admin = await staffActor(t, 'ADMIN');
    await admin.api.post('/v1/me/push-token', { token: 'live-token-0123456789abcdef', platform: 'android' }).expect(200);
    await admin.api.post('/v1/me/push-token', { token: 'dead-token-0123456789abcdef', platform: 'android' }).expect(200);
    expect(await t.prisma.pushToken.count({ where: { userId: admin.user.id } })).toBe(2);

    await t.app.get(AppNotifier).notify([admin.user.id], { type: 'test.push', title: 'Новая работа', body: 'Лента · 9 м', link: '/admin/job-requests' });
    const fcm = async () => calls.filter((c) => c.url.includes('fcm.googleapis.com'));
    for (let i = 0; i < 50 && (await fcm()).length < 2; i++) await new Promise((r) => setTimeout(r, 20));

    // the OAuth assertion is a real RS256 JWT signed with the service-account key
    const tokenCall = calls.find((c) => c.url.includes('oauth2'))!;
    const assertion = new URLSearchParams(tokenCall.body).get('assertion')!;
    const [h, p, sig] = assertion.split('.');
    expect(createVerify('RSA-SHA256').update(`${h}.${p}`).verify(publicKey, Buffer.from(sig, 'base64url'))).toBe(true);
    expect(JSON.parse(Buffer.from(p, 'base64url').toString()).scope).toBe('https://www.googleapis.com/auth/firebase.messaging');

    const sent = (await fcm()).map((c) => JSON.parse(c.body).message);
    expect(sent).toHaveLength(2);
    expect(sent[0].notification).toBeUndefined(); // data-only: the app shows it under the notice id (no doubles)
    expect(sent[0].data).toMatchObject({ title: 'Новая работа', body: 'Лента · 9 м', link: '/admin/job-requests' });
    expect(sent[0].data.id).toBeTruthy();
    expect((await fcm())[0].auth).toBe('Bearer ya29.test');

    for (let i = 0; i < 50 && (await t.prisma.pushToken.count({ where: { token: 'dead-token-0123456789abcdef' } })) > 0; i++) await new Promise((r) => setTimeout(r, 20));
    expect(await t.prisma.pushToken.count({ where: { userId: admin.user.id } })).toBe(1);

    await admin.api.delete('/v1/me/push-token').send({ token: 'live-token-0123456789abcdef' }).expect(200);
    expect(await t.prisma.pushToken.count({ where: { userId: admin.user.id } })).toBe(0);
  });

  it('a token needs a signed-in user', async () => {
    const res = await (await import('supertest')).default(t.app.getHttpServer()).post('/v1/me/push-token').send({ token: 'x'.repeat(30) });
    expect(res.status).toBe(401);
  });
});
