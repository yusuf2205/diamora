import 'reflect-metadata';
import { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import * as argon2 from 'argon2';
import { randomInt, randomUUID } from 'node:crypto';
import sharp from 'sharp';
import request from 'supertest';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/bootstrap-app';
import { PrismaService } from '../../src/prisma/prisma.module';
import { RegistrationService, type BotInput } from '../../src/registration/registration.service';
import { OutboxSender } from '../../src/worker/outbox';
import { EventBus } from '../../src/events/events.module';
import type { RealtimeEnvelope } from '@yusmus/shared';

export interface TestApp {
  app: NestExpressApplication;
  prisma: PrismaService;
  registration: RegistrationService;
  outbox: OutboxSender;
  bus: EventBus;
  events: RealtimeEnvelope[];
  close(): Promise<void>;
}

export async function createTestApp(env: Record<string, string> = {}): Promise<TestApp> {
  Object.assign(process.env, {
    NODE_ENV: 'test', LOG_LEVEL: process.env.TEST_LOG_LEVEL ?? 'silent', DATABASE_URL: process.env.TEST_DATABASE_URL,
    JWT_ACCESS_SECRET: 'test-jwt-secret-test-jwt-secret-1234', FILE_SIGNING_SECRET: 'test-file-secret-test-file-secret-12',
    STORAGE_DRIVER: 'memory', RATE_LIMIT_ENABLED: 'false', PUBLIC_API_URL: 'http://api.test', REDIS_URL: '', ...env,
  });
  delete process.env.REDIS_URL; // in-process event bus
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  const app = moduleRef.createNestApplication<NestExpressApplication>({ logger: false });
  configureApp(app);
  await app.init();
  const bus = app.get(EventBus);
  const events: RealtimeEnvelope[] = [];
  bus.subscribe((e) => events.push(e));
  return { app, prisma: app.get(PrismaService), registration: app.get(RegistrationService), outbox: new OutboxSender(app.get(PrismaService)), bus, events, close: () => app.close() };
}

const used = new Set<string>();
export function uniquePhone(): string {
  for (;;) {
    const p = `+998${900_000_000 + randomInt(0, 99_999_999)}`;
    if (!used.has(p)) { used.add(p); return p; }
  }
}
// The test database is shared by all spec files of a run: ids must be unique across files, not just within one.
const usedTg = new Set<number>();
export function nextTelegramId(): number {
  for (;;) {
    const id = randomInt(10_000_000_000, 9_000_000_000_000);
    if (!usedTg.has(id)) { usedTg.add(id); return id; }
  }
}

export const PASSWORD = 'Sup3r-Secret!';
const hashCache = argon2.hash(PASSWORD, { type: argon2.argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1 });

export async function createAdmin(t: TestApp, phone = uniquePhone()) {
  return t.prisma.user.create({ data: { phone, fullName: 'Admin Owner', role: 'ADMIN', passwordHash: await hashCache } });
}
/** Any staff role (D-028), with optional extra permission grants (created BEFORE login so the first session already has them). */
export async function createStaff(t: TestApp, role: 'SUPER_ADMIN' | 'ADMIN' | 'MANAGER', phone = uniquePhone(), permissions: string[] = []) {
  const user = await t.prisma.user.create({ data: { phone, fullName: `${role} Owner`, role, passwordHash: await hashCache } });
  if (permissions.length) await t.prisma.userPermission.createMany({ data: permissions.map((permission) => ({ userId: user.id, permission, granted: true })) });
  return user;
}

export interface Session { accessToken: string; refreshToken: string; user: { id: string; role: string; workerId: string | null; permissions: string[] } }
const device = (installId: string = randomUUID()) => ({ installId, platform: 'ANDROID', name: 'Test phone', appVersion: '0.1.0' });

export async function adminLogin(t: TestApp, phone: string, password = PASSWORD, installId?: string): Promise<Session> {
  const res = await request(t.app.getHttpServer()).post('/v1/auth/admin/login').send({ phone, password, device: device(installId) });
  if (res.status !== 200) throw new Error(`admin login failed: ${res.status} ${JSON.stringify(res.body)}`);
  return res.body;
}
export async function adminActor(t: TestApp) {
  const user = await createAdmin(t);
  const session = await adminLogin(t, user.phone);
  return { user, session, api: client(t, session.accessToken) };
}
/** SUPER_ADMIN / ADMIN / MANAGER actor, with optional extra permission grants for the ADMIN/MANAGER case. */
export async function staffActor(t: TestApp, role: 'SUPER_ADMIN' | 'ADMIN' | 'MANAGER', permissions: string[] = []) {
  const user = await createStaff(t, role, undefined, permissions);
  const session = await adminLogin(t, user.phone);
  return { user, session, api: client(t, session.accessToken) };
}
export const superAdminActor = (t: TestApp) => staffActor(t, 'SUPER_ADMIN');

/** Full worker flow through the real service: registration via bot inputs -> (caller approves) -> code -> login. */
export const text = (t: string): BotInput => ({ kind: 'text', text: t });
export const action = (a: Extract<BotInput, { kind: 'action' }>['action']): BotInput => ({ kind: 'action', action: a });

export async function registerViaBot(t: TestApp, opts: { name?: string; phone?: string; type?: 'MONEY' | 'ITEM'; telegramId?: number } = {}) {
  const tgId = opts.telegramId ?? nextTelegramId();
  const phone = opts.phone ?? uniquePhone();
  const ctx = { telegramUserId: BigInt(tgId), chatId: BigInt(tgId) };
  const send = (i: BotInput) => t.registration.process(ctx, i);
  await send({ kind: 'command', command: 'start' });
  await send(text(opts.name ?? 'Малика Каримова'));
  await send({ kind: 'contact', phone: phone.replace('+', ''), contactUserId: tgId });
  await send(action('skip'));
  await send({ kind: 'location', latitude: 41.2995, longitude: 69.2401 });
  if ((opts.type ?? 'MONEY') === 'MONEY') {
    await send(action('type_money'));
    await send(text('1 500 000'));
  } else {
    await send(action('type_item'));
    await send(text('Золотое кольцо 585'));
    const img = await jpeg();
    await send({ kind: 'photo', download: async () => ({ buffer: img, filename: 'ring.jpg' }) });
    await send(action('photos_done'));
  }
  await send(action('skip'));
  const done = await send(action('confirm'));
  return { tgId, phone, ctx, send, done };
}

export function client(t: TestApp, token?: string) {
  const server = t.app.getHttpServer();
  const auth = (r: request.Test) => (token ? r.set('Authorization', `Bearer ${token}`) : r);
  return {
    get: (url: string) => auth(request(server).get(url)),
    post: (url: string, body?: object) => auth(request(server).post(url)).send(body),
    put: (url: string, body?: object) => auth(request(server).put(url)).send(body),
    patch: (url: string, body?: object) => auth(request(server).patch(url)).send(body),
    delete: (url: string) => auth(request(server).delete(url)),
    upload: (url: string, file: Buffer, filename: string, fields: Record<string, string> = {}) => {
      let r = auth(request(server).post(url));
      for (const [k, v] of Object.entries(fields)) r = r.field(k, v);
      return r.attach('file', file, filename);
    },
  };
}

export async function jpeg(color = { r: 200, g: 30, b: 30 }, w = 64, h = 48): Promise<Buffer> {
  return sharp({ create: { width: w, height: h, channels: 3, background: color } }).jpeg().toBuffer();
}

/** Approves a registered worker as ADMIN, requests a login code and signs the worker in (reads the code from the outbox row). */
export async function approveAndLoginWorker(t: TestApp, admin: ReturnType<typeof client>, phone: string) {
  const list = await admin.get(`/v1/workers?q=${phone.slice(-7)}`).expect(200);
  const workerId: string = list.body.items[0].id;
  await admin.post(`/v1/workers/${workerId}/approve`, { collateralReceived: true }).expect(201);
  await request(t.app.getHttpServer()).post('/v1/auth/worker/code').send({ phone }).expect(200);
  const note = await t.prisma.notification.findFirstOrThrow({ where: { workerId, type: 'login_code' }, orderBy: { createdAt: 'desc' } });
  const code = /(\d{6})/.exec(note.body ?? '')![1];
  const res = await request(t.app.getHttpServer()).post('/v1/auth/worker/login').send({ phone, code, device: device() });
  if (res.status !== 200) throw new Error(`worker login failed ${res.status} ${JSON.stringify(res.body)}`);
  return { workerId, session: res.body as Session, api: client(t, res.body.accessToken), code };
}
