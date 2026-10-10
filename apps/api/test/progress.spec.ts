import request from 'supertest';
import { AppNotifier } from '../src/notifications/app-notifier';
import { ProgressService } from '../src/progress/progress.service';
import { periodRange } from '../src/reports/reports.service';
import { approveAndLoginWorker, createTestApp, handOver, jpeg, registerViaBot, superAdminActor, TestApp } from './support/app';

describe('«Мой прогресс», defect photos, «Как шить», the quality bonus (owner, 2026-10-11)', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(async () => {
    await t.prisma.qualityBonusSettings.deleteMany({}); // a global setting: never leak it into other suites
    await t.close();
  });

  async function acceptedWork() {
    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const { workerId, api: workerApi } = await approveAndLoginWorker(t, admin.api, reg.phone);
    const tape = await admin.api.post('/v1/admin/materials', { name: `PTape ${reg.tgId}`, unit: 'METER', minStock: '0' }).expect(201);
    await admin.api.post('/v1/admin/stock/receipt', { materialId: tape.body.id, quantity: '100', comment: 'setup' }).expect(201);
    const kit = await admin.api.post('/v1/admin/kits', { name: `PKit ${reg.tgId}`, ribbonMeters: 9, items: [{ materialId: tape.body.id, requiredQuantity: '9' }] }).expect(201);
    const color = await admin.api.post('/v1/admin/colors', { name: `PColor ${reg.tgId}` }).expect(201);
    const item = await admin.api.post('/v1/admin/catalog', { name: `PModel ${reg.tgId}` }).expect(201);
    const v = await admin.api.post(`/v1/admin/catalog/${item.body.id}/variants`, { colorId: color.body.id }).expect(201);
    const variant = (v.body.variants as { id: string; color: { id: string } }[]).find((x) => x.color.id === color.body.id)!;
    const a = await admin.api.post('/v1/admin/assignments', { workerId, productModelId: item.body.id, productVariantId: variant.id, colorId: color.body.id, materialKitTemplateId: kit.body.id, kitCount: 2 }).expect(201);
    await handOver(admin.api, workerApi, a.body.id);
    await workerApi.post(`/v1/work/${a.body.id}/ready`, { readyMeters: '18' }).expect(200);
    await admin.api.post(`/v1/admin/assignments/${a.body.id}/pickup`, {}).expect(200);
    return { admin, workerId, workerApi, assignmentId: a.body.id as string, modelId: item.body.id as string };
  }

  it('a defect is shown to her with the photo and the inspector\'s words; her month, quality and the bonus forecast', async () => {
    const { admin, workerApi, assignmentId } = await acceptedWork();
    const photo = await request(t.app.getHttpServer()).post('/v1/admin/quality-photos').set('Authorization', `Bearer ${admin.session.accessToken}`)
      .attach('file', await jpeg(), 'defect.jpg').expect(201);
    expect(photo.body.thumbUrl).toContain('/v1/files/');
    await admin.api.post(`/v1/admin/assignments/${assignmentId}/accept`, {
      broughtMeters: '18', acceptedMeters: '17', defectiveMeters: '1', comment: 'Кривой шов на краю', photoFileIds: [photo.body.id],
    }).expect(200);

    await admin.api.put('/v1/admin/quality-bonus', { enabled: true, percent: 5, maxDefectPercent: 10, minMeters: 9 }).expect(200);
    const p = (await workerApi.get('/v1/work/progress').expect(200)).body;
    expect(p.thisMonth).toMatchObject({ acceptedMeters: 17, defectiveMeters: 1, qualityPercent: 94.4 });
    expect(p.allTime).toMatchObject({ acceptedMeters: 17, checks: 1 });
    expect(p.checks[0]).toMatchObject({ result: 'PARTIALLY_ACCEPTED', defectiveMeters: 1, comment: 'Кривой шов на краю' });
    expect(p.checks[0].photos).toHaveLength(1);
    expect(p.bonus).toMatchObject({ enabled: true, percent: 5, qualifies: true, defectPercent: 5.6 });
    expect(Number(p.bonus.expected)).toBe(Math.floor(Number(p.thisMonth.earned) * 5 / 100));
    expect(Number(p.ratePerKit)).toBeGreaterThan(0);

    // stricter rule: 1 m of 18 is too much -> no bonus this month
    await admin.api.put('/v1/admin/quality-bonus', { enabled: true, percent: 5, maxDefectPercent: 0, minMeters: 9 }).expect(200);
    expect((await workerApi.get('/v1/work/progress').expect(200)).body.bonus).toMatchObject({ qualifies: false, expected: '0' });
    await workerApi.put('/v1/admin/quality-bonus', { enabled: false, percent: 5, maxDefectPercent: 0, minMeters: 9 }).expect(403);
  });

  it('the bonus is paid once on the 1st for the month before, only to workers with few defects', async () => {
    const { admin, workerId, workerApi, assignmentId } = await acceptedWork();
    await admin.api.post(`/v1/admin/assignments/${assignmentId}/accept`, { broughtMeters: '18', acceptedMeters: '18' }).expect(200);
    await admin.api.put('/v1/admin/quality-bonus', { enabled: true, percent: 10, maxDefectPercent: 0, minMeters: 9 }).expect(200);
    await t.prisma.qualityBonusSettings.update({ where: { id: 1 }, data: { lastPaidMonth: null } });
    const earned = (await t.prisma.workerLedgerTransaction.aggregate({ _sum: { amount: true }, where: { workerId, type: 'EARNING' } }))._sum.amount!;

    const nextMonth = new Date(periodRange('month', 1).from.getTime() + 3_600_000);
    const progress = t.app.get(ProgressService);
    const notifier = t.app.get(AppNotifier, { strict: false });
    await progress.payMonthlyBonuses(notifier, nextMonth);
    await progress.payMonthlyBonuses(notifier, nextMonth); // twice: still once
    const bonuses = await t.prisma.workerLedgerTransaction.findMany({ where: { workerId, type: 'BONUS' } });
    expect(bonuses).toHaveLength(1);
    expect(bonuses[0].amount).toBe((earned * 10n) / 100n);
    expect(bonuses[0].comment).toMatch(/Бонус за качество/);
    const me = (await workerApi.get('/v1/work/earnings').expect(200)).body;
    expect(Number(me.earned)).toBe(Number(earned + bonuses[0].amount)); // «Заработано» includes the bonus
  });

  it('«Как шить»: a video on the model, seen by the worker from her work', async () => {
    const { admin, workerApi, modelId } = await acceptedWork();
    expect((await workerApi.get(`/v1/work/models/${modelId}/instruction`).expect(200)).body.video).toBeNull();
    // a tiny real MP4 header is enough for the sniffer: ftyp box
    const mp4 = Buffer.concat([Buffer.from([0, 0, 0, 0x18]), Buffer.from('ftypmp42'), Buffer.alloc(16)]);
    await request(t.app.getHttpServer()).post(`/v1/admin/catalog/${modelId}/instruction`).set('Authorization', `Bearer ${admin.session.accessToken}`)
      .attach('file', mp4, 'how-to.mp4').expect(200);
    const seen = (await workerApi.get(`/v1/work/models/${modelId}/instruction`).expect(200)).body;
    expect(seen.video.url).toContain('/v1/files/');
    await admin.api.delete(`/v1/admin/catalog/${modelId}/instruction`).expect(200);
    expect((await workerApi.get(`/v1/work/models/${modelId}/instruction`).expect(200)).body.video).toBeNull();
  });
});
