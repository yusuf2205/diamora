import { CHAT_CHUNK_BYTES } from '@diamoraa/shared';
import { createTestApp, jpeg, staffActor, TestApp } from './support/app';

/** Big videos in parts (resumable), a preview picture, and playback while downloading (HTTP byte ranges). */
describe('chat media', () => {
  let t: TestApp;
  beforeAll(async () => { t = await createTestApp(); });
  afterAll(async () => { await t.close(); });

  const mp4 = (size: number) => {
    const b = Buffer.alloc(size, 7);
    Buffer.from([0, 0, 0, 0x20]).copy(b, 0);
    Buffer.from('ftypisom').copy(b, 4);
    return b;
  };
  const pathOf = (url: string) => { const u = new URL(url); return u.pathname + u.search; };

  it('a 12 MB video in 3 parts: a dropped connection resumes (the server says which parts it has); preview picture; one message', async () => {
    const a = await staffActor(t, 'ADMIN');
    const b = await staffActor(t, 'MANAGER');
    const room = (await a.api.post('/v1/chat/direct', { userId: b.user.id }).expect(200)).body;
    const video = mp4(12 * 1024 * 1024);
    const start = { name: 'IMG_0042.MOV', size: video.length, kind: 'VIDEO', clientId: 'vid-000000001', durationMs: 34000, width: 1080, height: 1920 };
    const s1 = (await a.api.post(`/v1/chat/rooms/${room.id}/uploads`, start).expect(200)).body;
    expect(s1).toMatchObject({ chunkSize: CHAT_CHUNK_BYTES, parts: 3, received: [] });
    const part = (i: number) => video.subarray(i * CHAT_CHUNK_BYTES, Math.min(video.length, (i + 1) * CHAT_CHUNK_BYTES));
    const sendPart = (i: number) => a.api.post(`/v1/chat/uploads/${s1.uploadId}/parts/${i}`).attach('chunk', part(i), 'chunk');
    await sendPart(0).expect(200);
    // ... the connection drops; the app starts the same send again and only sends what is missing
    const s2 = (await a.api.post(`/v1/chat/rooms/${room.id}/uploads`, start).expect(200)).body;
    expect(s2.uploadId).toBe(s1.uploadId);
    expect(s2.received).toEqual([0]);
    await a.api.post(`/v1/chat/uploads/${s1.uploadId}/complete`).expect(400); // parts missing
    await sendPart(1).expect(200);
    await sendPart(2).expect(200);
    await a.api.post(`/v1/chat/uploads/${s1.uploadId}/parts/1`).attach('chunk', Buffer.alloc(10), 'c').expect(400); // wrong size
    const msg = (await a.api.post(`/v1/chat/uploads/${s1.uploadId}/complete`).attach('thumb', await jpeg(), 'thumb.jpg').expect(201)).body;
    expect(msg).toMatchObject({ kind: 'VIDEO', file: { size: video.length, mimeType: 'video/mp4', durationMs: 34000, width: 1080, height: 1920, name: 'IMG_0042.MOV' } });
    expect(msg.file.thumbUrl).toContain('/thumb');
    // a retry after success is the same message, never a second one
    expect((await a.api.post(`/v1/chat/rooms/${room.id}/uploads`, start).expect(200)).body).toMatchObject({ done: true, message: { id: msg.id } });

    // plays while downloading: byte ranges
    const head = await b.api.get(pathOf(msg.file.url)).set('Range', 'bytes=0-1023').expect(206);
    expect(head.headers['content-range']).toBe(`bytes 0-1023/${video.length}`);
    expect(head.headers['accept-ranges']).toBe('bytes');
    expect(Number(head.headers['content-length'])).toBe(1024);
    const tail = await b.api.get(pathOf(msg.file.url)).set('Range', `bytes=${video.length - 10}-`).expect(206);
    expect(tail.headers['content-range']).toBe(`bytes ${video.length - 10}-${video.length - 1}/${video.length}`);
    await b.api.get(pathOf(msg.file.url)).set('Range', `bytes=${video.length + 5}-`).expect(416);
    const thumb = await b.api.get(pathOf(msg.file.thumbUrl)).expect(200);
    expect(thumb.headers['content-type']).toBe('image/jpeg');
  });

  it('limits: a video up to 150 MB, anything else up to 50 MB; only my own upload', async () => {
    const a = await staffActor(t, 'ADMIN');
    const b = await staffActor(t, 'MANAGER');
    const room = (await a.api.post('/v1/chat/direct', { userId: b.user.id }).expect(200)).body;
    await a.api.post(`/v1/chat/rooms/${room.id}/uploads`, { name: 'big.mp4', size: 151 * 1024 * 1024, kind: 'VIDEO', clientId: 'vid-000000002' }).expect(400);
    await a.api.post(`/v1/chat/rooms/${room.id}/uploads`, { name: 'big.zip', size: 60 * 1024 * 1024, kind: 'FILE', clientId: 'doc-000000003' }).expect(422);
    const ok = (await a.api.post(`/v1/chat/rooms/${room.id}/uploads`, { name: 'v.mp4', size: 140 * 1024 * 1024, kind: 'VIDEO', clientId: 'vid-000000004' }).expect(200)).body;
    expect(ok.parts).toBe(28);
    await b.api.post(`/v1/chat/uploads/${ok.uploadId}/parts/0`).attach('chunk', Buffer.alloc(CHAT_CHUNK_BYTES), 'c').expect(404); // not his
  });
});
