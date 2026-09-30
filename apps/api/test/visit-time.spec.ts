import { visitTimeText } from '@diamoraa/shared';
import { approveAndLoginWorker, createTestApp, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

/** «Удобное время»: she says when staff may come; staff see it in words on her card and on the map. */
describe('visit time', () => {
  let t: TestApp;
  beforeAll(async () => { t = await createTestApp(); });
  afterAll(async () => { await t.close(); });

  it('in words: ranges of days, every day, a note', () => {
    expect(visitTimeText({ days: [1, 2, 3, 4, 5], from: '10:00', to: '18:00' })).toBe('Пн–Пт 10:00–18:00');
    expect(visitTimeText({ days: [6, 1, 3], from: '09:00', to: '12:00', note: 'звонить заранее' })).toBe('Пн, Ср, Сб 09:00–12:00 · звонить заранее');
    expect(visitTimeText({ days: [1, 2, 3, 4, 5, 6, 7], from: '08:00', to: '20:00' })).toBe('Каждый день 08:00–20:00');
    expect(visitTimeText(null)).toBeNull();
  });

  it('the worker sets it; staff see it on her card; «с» must be before «до»; staff can set it for her; null clears it', async () => {
    const admin = await superAdminActor(t);
    const w = await approveAndLoginWorker(t, admin.api, (await registerViaBot(t)).phone);
    expect((await w.api.get('/v1/work/visit-time').expect(200)).body).toEqual({ visitTime: null, visitText: null });
    await w.api.put('/v1/work/visit-time', { visitTime: { days: [1, 2, 3, 4, 5], from: '18:00', to: '10:00' } }).expect(400);
    const set = (await w.api.put('/v1/work/visit-time', { visitTime: { days: [5, 1, 2, 3, 4], from: '10:00', to: '18:00', note: 'звонить заранее' } }).expect(200)).body;
    expect(set.visitText).toBe('Пн–Пт 10:00–18:00 · звонить заранее');
    expect((await admin.api.get(`/v1/workers/${w.workerId}`).expect(200)).body.visitText).toBe('Пн–Пт 10:00–18:00 · звонить заранее');

    await admin.api.put(`/v1/admin/workers/${w.workerId}/visit-time`, { visitTime: { days: [6], from: '09:00', to: '12:00' } }).expect(200);
    expect((await w.api.get('/v1/work/visit-time').expect(200)).body.visitText).toBe('Сб 09:00–12:00');
    const stranger = await staffActor(t, 'MANAGER', ['WORKER_UPDATE']);
    await stranger.api.put(`/v1/admin/workers/${w.workerId}/visit-time`, { visitTime: null }).expect(404); // not her manager
    await w.api.put('/v1/work/visit-time', { visitTime: null }).expect(200);
    expect((await w.api.get('/v1/work/visit-time').expect(200)).body.visitTime).toBeNull();
  });
});
