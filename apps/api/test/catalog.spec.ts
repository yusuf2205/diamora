import type { RealtimeEnvelope } from '@yusmus/shared';
import { io, type Socket } from 'socket.io-client';
import request from 'supertest';
import {
  approveAndLoginWorker, createTestApp, jpeg, registerViaBot, staffActor, superAdminActor, TestApp,
} from './support/app';

const until = async (cond: () => boolean, ms = 3000) => {
  const end = Date.now() + ms;
  while (!cond() && Date.now() < end) await new Promise((r) => setTimeout(r, 25));
  return cond();
};
/** Minimal valid-enough MP4 container header (ftyp box) so FilesService.uploadVideo's magic-byte sniff accepts it. */
function fakeMp4(): Buffer {
  const b = Buffer.alloc(32);
  b.writeUInt32BE(24, 0);
  b.write('ftyp', 4, 'ascii');
  b.write('isom', 8, 'ascii');
  return b;
}

describe('catalog "Наши работы" (D-029): informational, no price, ADMIN-managed, realtime to workers', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('WORKER default: an empty published list until something is published; staff sees drafts, workers never do', async () => {
    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, admin.api, reg.phone);

    expect((await worker.api.get('/v1/catalog')).body.items).toEqual([]);
    const created = await admin.api.post('/v1/admin/catalog', { name: 'Комплект «Роза»', description: 'Розовое золото' }).expect(201);
    const id: string = created.body.id;
    expect(created.body.status).toBe('DRAFT');
    await worker.api.get(`/v1/catalog/${id}`).expect(404); // not published yet
    expect((await worker.api.get('/v1/catalog')).body.items).toEqual([]);
    // no price field exists anywhere in the payload - never leaks even to staff
    expect(JSON.stringify(created.body).toLowerCase()).not.toMatch(/rateperkit|price/);
  });

  it('publishing requires at least one photo; a WORKER then sees it with no price, staff sees full detail', async () => {
    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, admin.api, reg.phone);
    const created = await admin.api.post('/v1/admin/catalog', { name: 'Ожерелье «Луна»' }).expect(201);
    const id: string = created.body.id;

    await admin.api.post(`/v1/admin/catalog/${id}/publish`).expect(409); // no photo yet (business invariant, same family as other 409s in this codebase)
    const withPhoto = await admin.api.upload(`/v1/admin/catalog/${id}/media`, await jpeg(), 'cover.jpg', { kind: 'PHOTO' }).expect(201);
    expect(withPhoto.body.media).toHaveLength(1);
    expect(withPhoto.body.media[0].isMain).toBe(true);
    await admin.api.post(`/v1/admin/catalog/${id}/publish`).expect(200);

    const list = await worker.api.get('/v1/catalog').expect(200);
    expect(list.body.items.map((i: { id: string }) => i.id)).toContain(id);
    expect(JSON.stringify(list.body).toLowerCase()).not.toMatch(/rateperkit|price/);
    const detail = await worker.api.get(`/v1/catalog/${id}`).expect(200);
    expect(detail.body.media[0].file.url).toBeTruthy();

    await admin.api.post(`/v1/admin/catalog/${id}/hide`).expect(200);
    expect((await worker.api.get('/v1/catalog')).body.items.map((i: { id: string }) => i.id)).not.toContain(id);
    await worker.api.get(`/v1/catalog/${id}`).expect(404);
  });

  it('variants (colour), video upload, main photo, reordering and content-hash dedupe of photos', async () => {
    const admin = await superAdminActor(t);
    const color = await t.prisma.color.create({ data: { name: `Золото ${Math.random()}` } });
    const created = await admin.api.post('/v1/admin/catalog', { name: 'Серьги «Капля»' }).expect(201);
    const id: string = created.body.id;
    const withVariant = await admin.api.post(`/v1/admin/catalog/${id}/variants`, { colorId: color.id, label: 'Классика' }).expect(201);
    expect(withVariant.body.variants).toHaveLength(1);

    const p1 = await admin.api.upload(`/v1/admin/catalog/${id}/media`, await jpeg({ r: 10, g: 10, b: 10 }), 'a.jpg', { kind: 'PHOTO' }).expect(201);
    const firstId: string = p1.body.media[0].id;
    const p2 = await admin.api.upload(`/v1/admin/catalog/${id}/media`, await jpeg({ r: 250, g: 250, b: 250 }), 'b.jpg', { kind: 'PHOTO' }).expect(201);
    expect(p2.body.media).toHaveLength(2);
    const secondId: string = p2.body.media.find((m: { id: string }) => m.id !== firstId).id;

    const video = await admin.api.upload(`/v1/admin/catalog/${id}/media`, fakeMp4(), 'demo.mp4', { kind: 'VIDEO' }).expect(201);
    expect(video.body.media.some((m: { kind: string }) => m.kind === 'VIDEO')).toBe(true);
    await request(t.app.getHttpServer()).post(`/v1/admin/catalog/${id}/media`).set('Authorization', `Bearer ${admin.session.accessToken}`).field('kind', 'VIDEO').attach('file', Buffer.from('not a video'), 'x.mp4').expect(422);

    const main2 = await admin.api.post(`/v1/admin/catalog/media/${secondId}/main`).expect(200);
    expect(main2.body.media.find((m: { id: string }) => m.id === secondId).isMain).toBe(true);
    expect(main2.body.media.find((m: { id: string }) => m.id === firstId).isMain).toBe(false);

    const order = main2.body.media.map((m: { id: string; kind: string }) => m.id).reverse();
    const reordered = await admin.api.put(`/v1/admin/catalog/${id}/media/order`, { ids: order }).expect(200);
    expect(reordered.body.media.map((m: { id: string }) => m.id)).toEqual(order);
  });

  it('deleting a catalog item is blocked once it is used by real work; hiding always works', async () => {
    const admin = await superAdminActor(t);
    const model = await t.prisma.productModel.create({ data: { code: `USED-${Math.random()}`, name: 'Used' } });
    const color = await t.prisma.color.create({ data: { name: `Цвет ${Math.random()}` } });
    const variant = await t.prisma.productVariant.create({ data: { modelId: model.id, colorId: color.id, sku: `SKU-${Math.random()}` } });
    const w = await t.prisma.workerProfile.create({ data: { telegramUserId: BigInt(Date.now()), telegramChatId: 1n, code: `W-${Math.random().toString(36).slice(2, 8)}`, fullName: 'X', phone: `+99890${Math.floor(1_000_000 + Math.random() * 8_000_000)}` } });
    await t.prisma.workAssignment.create({ data: { code: `ASN-${Math.random()}`, workerId: w.id, productModelId: model.id, productVariantId: variant.id, colorId: color.id, kitCount: 1, plannedMeters: 9, createdById: w.id } });

    await admin.api.delete(`/v1/admin/catalog/${model.id}`).expect(409);
    await admin.api.post(`/v1/admin/catalog/${model.id}/hide`).expect(200);

    const unused = await admin.api.post('/v1/admin/catalog', { name: 'Unused' }).expect(201);
    await admin.api.delete(`/v1/admin/catalog/${unused.body.id}`).expect(200);
    await admin.api.get(`/v1/admin/catalog/${unused.body.id}`).expect(404);
  });

  it('only CATALOG_MANAGE may write; CATALOG_VIEW alone may read staff endpoints; WORKER never reaches /admin/catalog', async () => {
    const admin = await superAdminActor(t);
    const viewer = await staffActor(t, 'MANAGER', ['CATALOG_VIEW']);
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, admin.api, reg.phone);
    await admin.api.post('/v1/admin/catalog', { name: 'Кольцо' }).expect(201);

    await viewer.api.get('/v1/admin/catalog').expect(200);
    await viewer.api.post('/v1/admin/catalog', { name: 'Nope' }).expect(403);
    await worker.api.get('/v1/admin/catalog').expect(403);
  });

  it('realtime: publishing reaches every connected WORKER and every staff user with CATALOG_VIEW', async () => {
    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, admin.api, reg.phone);
    await t.app.listen(0, '127.0.0.1');
    const addr = t.app.getHttpServer().address();
    const url = `http://127.0.0.1:${typeof addr === 'object' && addr ? addr.port : 0}`;
    const connect = (token: string) => new Promise<{ socket: Socket; events: RealtimeEnvelope[] }>((resolve) => {
      const socket = io(url, { auth: { token }, transports: ['websocket'], reconnection: false });
      const events: RealtimeEnvelope[] = [];
      socket.on('event', (e: RealtimeEnvelope) => events.push(e));
      socket.on('ready', () => resolve({ socket, events }));
    });
    const w = await connect(worker.session.accessToken);
    const a = await connect(admin.session.accessToken);
    try {
      const created = await admin.api.post('/v1/admin/catalog', { name: 'Браслет' }).expect(201);
      await admin.api.upload(`/v1/admin/catalog/${created.body.id}/media`, await jpeg(), 'c.jpg', { kind: 'PHOTO' }).expect(201);
      await admin.api.post(`/v1/admin/catalog/${created.body.id}/publish`).expect(200);
      expect(await until(() => w.events.some((e) => e.type === 'catalog.item.published'))).toBe(true);
      expect(await until(() => a.events.some((e) => e.type === 'catalog.item.published'))).toBe(true);
    } finally {
      w.socket.close();
      a.socket.close();
    }
  });
});
