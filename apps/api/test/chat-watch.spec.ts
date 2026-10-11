import { roomsForEvent, roomsForUser, CHAT_WATCH_ROOM } from '@diamoraa/shared';
import { createTestApp, staffActor, superAdminActor, TestApp } from './support/app';

/** «Все переписки» (owner, 2026-10-11): the SUPER_ADMIN sees every conversation, read-only, live - and nobody else does. */
describe('chat oversight', () => {
  let t: TestApp;
  beforeAll(async () => { t = await createTestApp(); });
  afterAll(async () => { await t.close(); });

  it('the SUPER_ADMIN lists and reads any chat without joining it; she leaves no «прочитано»; she can delete a message', async () => {
    const boss = await superAdminActor(t);
    const a = await staffActor(t, 'MANAGER');
    const b = await staffActor(t, 'ADMIN');
    const room = (await a.api.post('/v1/chat/direct', { userId: b.user.id }).expect(200)).body;
    const msg = (await a.api.post(`/v1/chat/rooms/${room.id}/messages`, { text: 'Секретик про поставщика' }).expect(201)).body;

    const list = (await boss.api.get('/v1/chat/watch/rooms').expect(200)).body.items;
    const row = list.find((r: { id: string }) => r.id === room.id);
    expect(row).toMatchObject({ kind: 'DIRECT', messageCount: 1, lastMessage: { text: 'Секретик про поставщика' } });
    expect(row.title).toContain(a.user.fullName);
    expect(row.title).toContain(b.user.fullName);
    expect((await boss.api.get(`/v1/chat/watch/rooms?q=${encodeURIComponent(b.user.fullName)}`).expect(200)).body.items.map((r: { id: string }) => r.id)).toContain(room.id);

    const detail = (await boss.api.get(`/v1/chat/rooms/${room.id}`).expect(200)).body;
    expect(detail).toMatchObject({ watching: true, canWrite: false, canManage: false });
    expect((await boss.api.get(`/v1/chat/rooms/${room.id}/messages`).expect(200)).body.items[0].text).toBe('Секретик про поставщика');
    expect(await t.prisma.auditLog.count({ where: { action: 'chat.watch', entityId: room.id, actorId: boss.user.id } })).toBe(1);
    await boss.api.post(`/v1/chat/rooms/${room.id}/read`).expect(200);
    expect(await t.prisma.chatMember.count({ where: { roomId: room.id, userId: boss.user.id } })).toBe(0); // never joined
    await boss.api.post(`/v1/chat/rooms/${room.id}/messages`, { text: 'я тут' }).expect(404); // read-only

    await boss.api.delete(`/v1/chat/messages/${msg.id}`).expect(200);
    expect((await t.prisma.chatMessage.findUniqueOrThrow({ where: { id: msg.id } })).deletedAt).not.toBeNull();

    // nobody else
    await b.api.get('/v1/chat/watch/rooms').expect(403);
    const other = await staffActor(t, 'ADMIN');
    await other.api.get(`/v1/chat/rooms/${room.id}/messages`).expect(404);
  });

  it('a deleted message is gone for everyone - only the SUPER_ADMIN still sees what it said and who deleted it', async () => {
    const boss = await superAdminActor(t);
    const a = await staffActor(t, 'MANAGER');
    const b = await staffActor(t, 'ADMIN');
    const room = (await a.api.post('/v1/chat/direct', { userId: b.user.id }).expect(200)).body;
    await a.api.post(`/v1/chat/rooms/${room.id}/messages`, { text: 'остаётся' }).expect(201);
    const msg = (await a.api.post(`/v1/chat/rooms/${room.id}/messages`, { text: 'Скидка поставщику 20%' }).expect(201)).body;
    await a.api.delete(`/v1/chat/messages/${msg.id}`).expect(200);

    for (const who of [a, b]) {
      const items = (await who.api.get(`/v1/chat/rooms/${room.id}/messages`).expect(200)).body.items;
      expect(items.map((m: { id: string }) => m.id)).not.toContain(msg.id);
      expect(items[0].text).toBe('остаётся'); // the chat list's last message too
      expect((await who.api.get(`/v1/chat/rooms/${room.id}/messages?after=${items[0].id}`).expect(200)).body.items).toHaveLength(0);
    }
    const seen = (await boss.api.get(`/v1/chat/rooms/${room.id}/messages`).expect(200)).body.items.find((m: { id: string }) => m.id === msg.id);
    expect(seen).toMatchObject({ deleted: true, text: 'Скидка поставщику 20%', kind: 'TEXT', deletedBy: { id: a.user.id, fullName: a.user.fullName } });
    expect(seen.deletedBy.at).toEqual(expect.any(String));
  });

  it('live: chat activity reaches the SUPER_ADMIN\'s sockets (not typing, not read receipts)', () => {
    expect(roomsForUser({ id: 's', role: 'SUPER_ADMIN', workerId: null, permissions: [] })).toContain(CHAT_WATCH_ROOM);
    expect(roomsForUser({ id: 'a', role: 'ADMIN', workerId: null, permissions: [] })).not.toContain(CHAT_WATCH_ROOM);
    const data = { roomId: 'r', messageId: 'm', senderId: 'x', userIds: ['x', 'y'] };
    expect(roomsForEvent('chat.message', data)).toContain(CHAT_WATCH_ROOM);
    expect(roomsForEvent('chat.typing', { ...data, userId: 'x', name: 'X', kind: 'text' })).not.toContain(CHAT_WATCH_ROOM);
    expect(roomsForEvent('chat.read', { roomId: 'r', userId: 'x', userIds: ['x'] })).not.toContain(CHAT_WATCH_ROOM);
  });
});
