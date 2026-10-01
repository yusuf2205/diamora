/**
 * The DEMO stack for recording the training videos (tools/tutorials): the whole API in one process on a fresh, EMPTY
 * local database, filled with made-up but realistic data (masters, work in every state, stock, orders, suppliers)
 * through the real services and endpoints - so every screen in the videos shows what the real system shows.
 *
 *   DEMO_SERVER=1 DATABASE_URL=postgresql://...local... node dist/cli/demo-server.js
 *
 * It refuses to start in production, against a non-local database, or on a database that already has users.
 * Also: POST /demo/worker-login {phone} plays the bot's part of a Telegram login (the emulator has no Telegram).
 */
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import * as argon2 from 'argon2';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { AppModule } from '../app.module';
import { AuthService } from '../auth/auth.service';
import { configureApp } from '../bootstrap-app';
import { PrismaService } from '../prisma/prisma.module';
import { RegistrationService, type BotInput } from '../registration/registration.service';

const PORT = Number(process.env.PORT ?? 3000);
const BASE = `http://localhost:${PORT}/v1`;
export const DEMO_PASSWORD = 'Demo-12345';
export const DEMO_STAFF = {
  SUPER_ADMIN: { phone: '+998900000001', name: 'Yusuf Adilov' },
  ADMIN: { phone: '+998900000002', name: 'Dilnoza Rahimova' },
  MANAGER: { phone: '+998900000003', name: 'Kamola Yusupova' },
} as const;
const WORKERS = [
  { name: 'Feruza Karimova', phone: '+998901110001', lat: 41.3111, lng: 69.2797 },
  { name: 'Malika Tosheva', phone: '+998901110002', lat: 41.3275, lng: 69.2289 },
  { name: 'Nigora Aliyeva', phone: '+998901110003', lat: 41.2856, lng: 69.2034 },
  { name: 'Sevara Usmonova', phone: '+998901110004', lat: 41.3402, lng: 69.3351 },
  { name: 'Gulnora Ismoilova', phone: '+998901110005', lat: 41.2646, lng: 69.2163 },
  { name: 'Madina Qodirova', phone: '+998901110006', lat: 41.3019, lng: 69.3108 },
];
const device = (installId: string = randomUUID()) => ({ installId, platform: 'ANDROID', name: 'Demo phone', appVersion: 'demo' });

function guard() {
  if (process.env.DEMO_SERVER !== '1') throw new Error('set DEMO_SERVER=1');
  if (process.env.NODE_ENV === 'production') throw new Error('never in production');
  const db = new URL(process.env.DATABASE_URL ?? '');
  if (!['localhost', '127.0.0.1'].includes(db.hostname)) throw new Error(`demo data only goes into a LOCAL database, not ${db.hostname}`);
}

async function main() {
  guard();
  Object.assign(process.env, {
    NODE_ENV: 'development', STORAGE_DRIVER: 'memory', RATE_LIMIT_ENABLED: 'false', PUBLIC_API_URL: process.env.DEMO_PUBLIC_URL ?? `http://localhost:${PORT}`, // the emulator reaches the host as 10.0.2.2
    JWT_ACCESS_SECRET: process.env.JWT_ACCESS_SECRET ?? 'demo-jwt-secret-demo-jwt-secret-1234', FILE_SIGNING_SECRET: process.env.FILE_SIGNING_SECRET ?? 'demo-file-secret-demo-file-secret-12',
    CORS_ORIGINS: process.env.CORS_ORIGINS ?? 'http://localhost:3001', SHOP_BOT_USERNAME: 'diamoraa_shop_bot',
  });
  delete process.env.REDIS_URL;
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { logger: ['error', 'warn'] });
  configureApp(app);
  const prisma = app.get(PrismaService);
  const registration = app.get(RegistrationService);
  const auth = app.get(AuthService);

  // the app's «Войти через Telegram»: remember the last /start token so /demo/worker-login can play the bot's part
  let lastStart: string | null = null;
  const original = auth.telegramSession.bind(auth);
  auth.telegramSession = async (d) => { const r = await original(d); lastStart = new URL(r.deepLink).searchParams.get('start'); return r; };
  const express = app.getHttpAdapter().getInstance() as import('express').Express;
  express.post('/demo/worker-login', async (req, res) => {
    const phone = String((req.query.phone as string) ?? '+998901110001');
    const w = await prisma.workerProfile.findFirst({ where: { user: { phone } } });
    if (!w || !lastStart) { res.status(404).json({ ok: false }); return; }
    const reply = await registration.process({ telegramUserId: w.telegramUserId!, chatId: w.telegramChatId! }, { kind: 'command', command: 'start', payload: lastStart });
    lastStart = null;
    // the bot's «Ilovaga qaytish» button: the recorder opens this link on the emulator
    res.json({ ok: true, handoffUrl: reply.telegramHandoffUrl ?? null });
  });

  await app.listen(PORT, '0.0.0.0');
  if ((await prisma.user.count()) > 0) {
    console.log(`demo: the database already has data - not seeding. API on ${BASE}`);
    return;
  }
  await seed(prisma, registration);
  console.log(`demo ready: API ${BASE}; staff password ${DEMO_PASSWORD}`);
}

// ---- seeding --------------------------------------------------------------------------------------------------------------
type Json = Record<string, unknown> & { id?: string };
function api(token?: string) {
  const call = async (method: string, path: string, body?: unknown): Promise<Json> => {
    const res = await fetch(`${BASE}${path}`, {
      method, headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}), 'idempotency-key': randomUUID() },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    if (!res.ok) throw new Error(`${method} ${path} -> ${res.status} ${text.slice(0, 300)}`);
    return text ? JSON.parse(text) : {};
  };
  return {
    get: (p: string) => call('GET', p), post: (p: string, b?: unknown) => call('POST', p, b ?? {}), patch: (p: string, b: unknown) => call('PATCH', p, b), put: (p: string, b: unknown) => call('PUT', p, b),
    upload: async (p: string, file: Buffer, name: string, fields: Record<string, string>) => {
      const fd = new FormData();
      for (const [k, v] of Object.entries(fields)) fd.append(k, v);
      fd.append('file', new Blob([new Uint8Array(file)], { type: 'image/jpeg' }), name);
      const res = await fetch(`${BASE}${p}`, { method: 'POST', headers: { authorization: `Bearer ${token}` }, body: fd });
      if (!res.ok) throw new Error(`upload ${p} -> ${res.status} ${(await res.text()).slice(0, 200)}`);
      return res.json() as Promise<Json>;
    },
  };
}

async function login(phone: string) {
  const r = await api().post('/auth/admin/login', { phone, password: DEMO_PASSWORD, device: device() });
  return api(r.accessToken as string);
}

/** registration exactly as through the bot, then approval, then a Telegram login (the bot's part played here) */
async function addWorker(registration: RegistrationService, admin: ReturnType<typeof api>, w: (typeof WORKERS)[number], tgId: number, approve: boolean) {
  const ctx = { telegramUserId: BigInt(tgId), chatId: BigInt(tgId) };
  const send = (i: BotInput) => registration.process(ctx, i);
  await send({ kind: 'command', command: 'start' });
  await send({ kind: 'text', text: w.name });
  await send({ kind: 'contact', phone: w.phone.replace('+', ''), contactUserId: tgId });
  await send({ kind: 'location', latitude: w.lat, longitude: w.lng });
  await send({ kind: 'action', action: 'type_money' });
  await send({ kind: 'text', text: '1 000 000' });
  await send({ kind: 'action', action: 'confirm' });
  const list = await admin.get(`/workers?q=${w.phone.slice(-7)}`);
  const workerId = (list.items as Json[])[0].id as string;
  if (!approve) return { workerId, api: null };
  await admin.post(`/workers/${workerId}/approve`, { collateralReceived: true });
  const s = await api().post('/auth/telegram/session', { device: device() });
  const start = new URL(s.deepLink as string).searchParams.get('start')!;
  const reply = await registration.process(ctx, { kind: 'command', command: 'start', payload: start });
  const ticket = new URL(reply.telegramHandoffUrl!).searchParams.get('t')!;
  const session = await api().post('/auth/telegram/exchange', { ticket, device: device() });
  return { workerId, api: api(session.accessToken as string) };
}

const PHOTO_COLORS = [{ r: 244, g: 166, b: 192 }, { r: 74, g: 144, b: 217 }, { r: 212, g: 175, b: 55 }, { r: 208, g: 49, b: 45 }];
/** the real catalog photos (public, the owner's own) - or a soft colour card when offline */
async function photo(i: number): Promise<Buffer> {
  try {
    const cat = (await (await fetch('https://diamoraa.uz/v1/public/catalog', { signal: AbortSignal.timeout(8000) })).json()) as { items: { coverPhoto: { url: string } | null }[] };
    const urls = cat.items.map((x) => x.coverPhoto?.url).filter(Boolean) as string[];
    if (urls.length) {
      const res = await fetch(urls[i % urls.length], { signal: AbortSignal.timeout(15000) });
      if (res.ok) return sharp(Buffer.from(await res.arrayBuffer())).jpeg({ quality: 85 }).toBuffer();
    }
  } catch { /* offline: the colour card below */ }
  const c = PHOTO_COLORS[i % PHOTO_COLORS.length];
  return sharp({ create: { width: 800, height: 800, channels: 3, background: c } }).jpeg().toBuffer();
}

async function seed(prisma: PrismaService, registration: RegistrationService) {
  const hash = await argon2.hash(DEMO_PASSWORD, { type: argon2.argon2id });
  for (const [role, s] of Object.entries(DEMO_STAFF)) {
    await prisma.user.create({ data: { phone: s.phone, fullName: s.name, role: role as 'ADMIN', passwordHash: hash } });
  }
  const boss = await login(DEMO_STAFF.SUPER_ADMIN.phone);
  await boss.put('/settings/company-contact', { phone: '+998 90 123 45 67', telegramUsername: 'diamoraa_uz' });

  // colours, materials, a 9 m kit
  const colors: Json[] = [];
  for (const [name, hex] of [['Pushti', '#F4A6C0'], ['Oq', '#FFFFFF'], ['Qora', '#222222'], ["Ko'k", '#4A90D9'], ['Oltin', '#D4AF37'], ['Qizil', '#D0312D']]) {
    colors.push(await boss.post('/admin/colors', { name, hex }));
  }
  const tape = await boss.post('/admin/materials', { name: 'Organza lenta 2 sm', unit: 'METER', minStock: '200' });
  const bead = await boss.post('/admin/materials', { name: 'Biser 4 mm', unit: 'GRAM', minStock: '2000' });
  const thread = await boss.post('/admin/materials', { name: 'Kapron ip', unit: 'PCS', minStock: '30' });
  await boss.post('/admin/stock/receipt', { materialId: tape.id, quantity: '600', comment: 'Boshlang‘ich qoldiq' });
  await boss.post('/admin/stock/receipt', { materialId: bead.id, quantity: '1500', comment: 'Boshlang‘ich qoldiq' });
  await boss.post('/admin/stock/receipt', { materialId: thread.id, quantity: '80', comment: 'Boshlang‘ich qoldiq' });
  const kit = await boss.post('/admin/kits', { name: 'Standart 9 m', ribbonMeters: 9, items: [{ materialId: tape.id, requiredQuantity: '9' }, { materialId: bead.id, requiredQuantity: '40' }, { materialId: thread.id, requiredQuantity: '1' }] });

  // catalog: published items with photos and colours
  const items: { id: string; variants: { id: string; colorId: string }[] }[] = [];
  const names = [['Oddiy tekis', 'Organza lenta, bir qator biser'], ['Kokil lenta', 'Ikki qator, to‘lqinsimon'], ['Gulli lenta', 'Har 5 sm da gul'], ['Marjon lenta', 'Katta biser, bayramona']];
  for (const [i, [name, description]] of names.entries()) {
    const it = await boss.post('/admin/catalog', { name, description });
    await boss.upload(`/admin/catalog/${it.id}/media`, await photo(i), `${i}.jpg`, { kind: 'PHOTO' });
    const variants: { id: string; colorId: string }[] = [];
    for (const c of colors.slice(i % 2, (i % 2) + 4)) {
      const r = await boss.post(`/admin/catalog/${it.id}/variants`, { colorId: c.id });
      const v = (r.variants as { id: string; color: { id: string } }[]).find((x) => x.color.id === c.id)!;
      variants.push({ id: v.id, colorId: c.id as string });
    }
    await boss.post(`/admin/catalog/${it.id}/publish`);
    items.push({ id: it.id as string, variants });
  }

  // masters: five working, one new application waiting for approval
  const masters: { workerId: string; api: ReturnType<typeof api> | null }[] = [];
  for (const [i, w] of WORKERS.entries()) masters.push(await addWorker(registration, boss, w, 7_000_000_000 + i, i < 5));
  const manager = await prisma.user.findFirstOrThrow({ where: { phone: DEMO_STAFF.MANAGER.phone } });
  for (const m of masters.slice(0, 4)) await boss.post(`/workers/${m.workerId}/manager`, { managerId: manager.id }).catch((e) => console.warn('demo seed:', (e as Error).message));
  await boss.put(`/admin/workers/${masters[0].workerId}/visit-time`, { visitTime: { days: [1, 2, 3, 4, 5], from: '10:00', to: '18:00', note: 'oldindan qo‘ng‘iroq qiling' } }).catch((e) => console.warn('demo seed:', (e as Error).message));
  await boss.put(`/admin/workers/${masters[1].workerId}/visit-time`, { visitTime: { days: [6, 7], from: '09:00', to: '13:00', note: null } }).catch((e) => console.warn('demo seed:', (e as Error).message));

  // work in every state
  const assign = (m: number, item: number, kits: number) => boss.post('/admin/assignments', {
    workerId: masters[m].workerId, productModelId: items[item].id, productVariantId: items[item].variants[0].id, colorId: items[item].variants[0].colorId, materialKitTemplateId: kit.id, kitCount: kits,
  });
  const handOver = async (id: string, worker: ReturnType<typeof api>) => {
    const started = await boss.post(`/admin/assignments/${id}/handoff`);
    const scan = await worker.post('/work/handoff/scan', { code: started.qrCode });
    await worker.post(`/work/handoff/${scan.handoffId}/confirm`);
  };
  // Feruza: two finished jobs (earned), part paid out
  for (const n of [0, 1]) {
    const a = await assign(0, n, 2);
    await handOver(a.id as string, masters[0].api!);
    await masters[0].api!.post(`/work/${a.id}/ready`, { readyMeters: '18' });
    await boss.post(`/admin/assignments/${a.id}/pickup`);
    await boss.post(`/admin/assignments/${a.id}/accept`, n === 0 ? { broughtMeters: '18', acceptedMeters: '18' } : { broughtMeters: '18', acceptedMeters: '17', defectiveMeters: '1' });
  }
  await boss.post(`/admin/workers/${masters[0].workerId}/payout`, { amount: '50000', comment: 'Naqd' });
  // Malika: working, 5 m done
  const b = await assign(1, 1, 1);
  await handOver(b.id as string, masters[1].api!);
  await masters[1].api!.post(`/work/${b.id}/progress`, { reportedMeters: '5' });
  // Nigora: ready to be picked up
  const c = await assign(2, 2, 2);
  await handOver(c.id as string, masters[2].api!);
  await masters[2].api!.post(`/work/${c.id}/ready`, { readyMeters: '18' });
  // Sevara: prepared, waiting to be delivered
  await assign(3, 3, 1);
  // Gulnora: brought back, waiting for the check
  const e = await assign(4, 0, 1);
  await handOver(e.id as string, masters[4].api!);
  await masters[4].api!.post(`/work/${e.id}/ready`, { readyMeters: '9' });
  await boss.post(`/admin/assignments/${e.id}/pickup`);

  // goals, suppliers, a purchase, customer orders
  await boss.put('/admin/goals', { monthlyMeters: 100 }).catch((e) => console.warn('demo seed:', (e as Error).message));
  const sup = await boss.post('/admin/suppliers', { name: 'Chorsu bozori — Biser', phone: '+998901234500', telegram: 'chorsu_biser' });
  await boss.patch(`/admin/materials/${bead.id}`, { supplierId: sup.id, unitCost: '120' }).catch(() => boss.patch(`/admin/materials/${bead.id}`, { supplierId: sup.id }));
  await boss.post('/admin/purchases', { supplierId: sup.id, items: [{ materialId: bead.id, quantity: '1000', unitPrice: '120' }] });
  const shop = api();
  await shop.post('/public/orders', { name: 'Zarina', phone: '+998 93 555 11 22', productModelId: items[0].id, lines: [{ colorName: 'Pushti', quantity: 20 }, { colorName: "Ko'k", quantity: 10 }], comment: 'Juma kuniga' });
  await shop.post('/public/orders', { name: 'Aziza', phone: '+998 97 444 33 22', productModelId: items[1].id, lines: [{ colorName: 'Oq', quantity: 15 }] });
  const panelOrder = await boss.post('/admin/orders', { name: 'Lola opa', phone: '+998 90 777 66 55', productModelId: items[2].id, lines: [{ colorName: 'Oltin', quantity: 30 }], comment: 'To‘y uchun' });
  await boss.patch(`/admin/orders/${panelOrder.id}`, { status: 'IN_WORK' });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
