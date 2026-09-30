import ExcelJS from 'exceljs';
import { periodRange } from '../src/reports/reports.service';
import { approveAndLoginWorker, createTestApp, handOver, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

describe('reports (day / week / month) and «Мои заработки по месяцам»', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('period ranges follow the Tashkent calendar (week starts on Monday)', () => {
    const now = new Date('2026-09-30T20:00:00Z'); // Thursday 01:00 in Tashkent (Oct 1)
    expect(periodRange('day', 0, now)).toEqual({ from: new Date('2026-09-30T19:00:00Z'), to: new Date('2026-10-01T19:00:00Z') });
    expect(periodRange('week', 0, now).from).toEqual(new Date('2026-09-27T19:00:00Z')); // Monday 28 Sep 00:00 Tashkent
    expect(periodRange('month', -1, now)).toEqual({ from: new Date('2026-08-31T19:00:00Z'), to: new Date('2026-09-30T19:00:00Z') });
  });

  it('this week: issued, accepted, earned and paid per worker; CSV for Excel; manager sees only her own; worker has her months', async () => {
    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const { workerId, api: workerApi } = await approveAndLoginWorker(t, admin.api, reg.phone);
    const tape = await admin.api.post('/v1/admin/materials', { name: `RTape ${reg.tgId}`, unit: 'METER', minStock: '0' }).expect(201);
    await admin.api.post('/v1/admin/stock/receipt', { materialId: tape.body.id, quantity: '100', comment: 'setup' }).expect(201);
    const kit = await admin.api.post('/v1/admin/kits', { name: `RKit ${reg.tgId}`, ribbonMeters: 9, items: [{ materialId: tape.body.id, requiredQuantity: '9' }] }).expect(201);
    const color = await admin.api.post('/v1/admin/colors', { name: `RColor ${reg.tgId}` }).expect(201);
    const item = await admin.api.post('/v1/admin/catalog', { name: `RModel ${reg.tgId}` }).expect(201);
    const v = await admin.api.post(`/v1/admin/catalog/${item.body.id}/variants`, { colorId: color.body.id }).expect(201);
    const variant = (v.body.variants as { id: string; color: { id: string } }[]).find((x) => x.color.id === color.body.id)!;
    const a = await admin.api.post('/v1/admin/assignments', { workerId, productModelId: item.body.id, productVariantId: variant.id, colorId: color.body.id, materialKitTemplateId: kit.body.id, kitCount: 1 }).expect(201);
    await handOver(admin.api, workerApi, a.body.id);
    await workerApi.post(`/v1/work/${a.body.id}/ready`, { readyMeters: '9' }).expect(200);
    await admin.api.post(`/v1/admin/assignments/${a.body.id}/pickup`, {}).expect(200);
    await admin.api.post(`/v1/admin/assignments/${a.body.id}/accept`, { broughtMeters: '9', acceptedMeters: '9' }).expect(200);
    await admin.api.post(`/v1/admin/workers/${workerId}/payout`, { amount: '10000' }).expect(200);

    const r = await admin.api.get('/v1/admin/reports?period=week').expect(200);
    const row = r.body.rows.find((x: { worker: { id: string } }) => x.worker.id === workerId);
    expect(row).toMatchObject({ issuedCount: 1, issuedMeters: 9, acceptedMeters: 9, paid: '10000' });
    expect(Number(row.earned)).toBeGreaterThan(0);

    const csv = await admin.api.get('/v1/admin/reports/export?period=week').expect(200);
    expect(csv.headers['content-type']).toContain('text/csv');
    expect(csv.text.charCodeAt(0)).toBe(0xfeff);
    expect(csv.text).toContain('"Мастерица";"Код"');

    // a real Excel file: the same rows, money as numbers; with a «мало» material too (its sheet name once broke the file)
    const low = (await admin.api.post('/v1/admin/materials', { name: `Мало ${Math.random()}`, unit: 'METER', minStock: '5' }).expect(201)).body.id;
    await admin.api.post('/v1/admin/stock/receipt', { materialId: low, quantity: '1' }).expect(201);
    const bin = await admin.api.get('/v1/admin/reports/export.xlsx?period=week').expect(200).buffer(true)
      .parse((res, cb) => { const parts: Buffer[] = []; res.on('data', (c: Buffer) => parts.push(c)); res.on('end', () => cb(null, Buffer.concat(parts))); });
    expect(bin.headers['content-type']).toContain('spreadsheetml');
    const wb = new ExcelJS.Workbook();
    await wb.xlsx.load(bin.body as never);
    const ws = wb.getWorksheet('Мастерицы')!;
    expect(String(ws.getCell('A1').value)).toContain('Diamoraa — отчёт');
    expect(ws.getRow(3).getCell(1).value).toBe('Мастерица');
    const found = ws.getSheetValues().find((r) => Array.isArray(r) && r[2] === row.worker.code) as unknown[];
    expect(found[5]).toBe(9); // accepted metres
    expect(found[8]).toBe(10000); // paid, a number Excel can sum
    expect(wb.getWorksheet('Склад — мало')).toBeTruthy();

    const mgr = await staffActor(t, 'MANAGER', ['FINANCE_VIEW_ASSIGNED']);
    const mine = await mgr.api.get('/v1/admin/reports?period=week').expect(200);
    expect(mine.body.rows.some((x: { worker: { id: string } }) => x.worker.id === workerId)).toBe(false);
    await workerApi.get('/v1/admin/reports').expect(403);

    const months = await workerApi.get('/v1/work/earnings/monthly').expect(200);
    expect(months.body.items).toHaveLength(6);
    expect(months.body.items[0]).toMatchObject({ acceptedMeters: 9, paid: '10000' });
  });
});
