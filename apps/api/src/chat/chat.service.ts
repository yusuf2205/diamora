import { Controller, Delete, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Patch, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { Prisma, type ChatMessage, type ChatRoom } from '@diamoraa/database';
import {
  CHAT_MAX_FILE_BYTES, chatContactsQuerySchema, chatDirectSchema, chatFileFieldsSchema, chatGroupSchema, chatGroupUpdateSchema,
  chatMessagesQuerySchema, chatTextSchema, scopeFor, type ChatMessageKind,
} from '@diamoraa/shared';
import { z } from 'zod';
import { ApiZodBody, Authenticated, CurrentUser } from '../common/decorators';
import { AppError, fileRejected, forbidden, notFound, validationFailed } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { FilesService } from '../files/files.service';
import { PushService } from '../notifications/push.service';
import { PresenceModule, PresenceService } from '../presence/presence.service';
import { PrismaService } from '../prisma/prisma.module';

/** The one chat of everyone: a fixed id, created on first use. */
export const COMPANY_ROOM_ID = '00000000-0000-4000-8000-00000000c4a7';

const PREVIEW: Record<Exclude<ChatMessageKind, 'TEXT'>, string> = {
  IMAGE: '📷 Фото', VIDEO: '🎬 Видео', VOICE: '🎤 Голосовое сообщение', AUDIO: '🎵 Аудио', FILE: '📎 Файл',
};
const isAdmin = (u: AuthUser) => u.role === 'SUPER_ADMIN' || u.role === 'ADMIN';
const directKey = (a: string, b: string) => [a, b].sort().join(':');

type Sender = { id: string; fullName: string; role: string } | null;
type MessageRow = ChatMessage & { sender: Sender };

/** Real bytes decide what a file is (the phone's claim is only a hint). */
function sniff(buf: Buffer): { family: 'video' | 'audio' | 'mp4'; mime: string; ext: string } | null {
  const ascii = (a: number, b: number) => (buf.length >= b ? buf.toString('ascii', a, b) : '');
  if (ascii(4, 8) === 'ftyp') {
    const brand = ascii(8, 12);
    if (brand === 'qt  ') return { family: 'video', mime: 'video/quicktime', ext: 'mov' };
    if (/^M4A|^M4B/.test(brand)) return { family: 'audio', mime: 'audio/mp4', ext: 'm4a' };
    return { family: 'mp4', mime: 'video/mp4', ext: 'mp4' }; // mp4 container: video or audio-only (voice), decided by the kind
  }
  if (buf.length > 4 && buf[0] === 0x1a && buf[1] === 0x45 && buf[2] === 0xdf && buf[3] === 0xa3) return { family: 'mp4', mime: 'video/webm', ext: 'webm' };
  if (ascii(0, 4) === 'OggS') return { family: 'audio', mime: 'audio/ogg', ext: 'ogg' };
  if (ascii(0, 3) === 'ID3' || (buf.length > 2 && buf[0] === 0xff && (buf[1] & 0xe0) === 0xe0)) return { family: 'audio', mime: 'audio/mpeg', ext: 'mp3' };
  if (ascii(0, 4) === 'RIFF' && ascii(8, 12) === 'WAVE') return { family: 'audio', mime: 'audio/wav', ext: 'wav' };
  if (ascii(0, 4) === '#!AM') return { family: 'audio', mime: 'audio/amr', ext: 'amr' };
  return null;
}

function safeExt(name: string | undefined): string {
  const m = /\.([A-Za-z0-9]{1,8})$/.exec(name ?? '');
  return m ? m[1].toLowerCase() : 'bin';
}

/**
 * Chat, everyone with everyone (owner's decision): direct chats, groups, and one company-wide chat. Messages are text or
 * one file (photo, video, voice, audio, document) up to 50 MB. Only members read a room (a non-member gets 404, not
 * 403: rooms are not enumerable). New messages reach members at once over the socket (chat.message) and as a push.
 */
@Injectable()
export class ChatService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly files: FilesService,
    private readonly events: EventBus,
    private readonly push: PushService,
    private readonly presence: PresenceService,
  ) {}

  // ---- rooms ------------------------------------------------------------------------------------------------------------
  private async companyRoom(): Promise<ChatRoom> {
    return this.prisma.chatRoom.upsert({ where: { id: COMPANY_ROOM_ID }, create: { id: COMPANY_ROOM_ID, kind: 'COMPANY' }, update: {} });
  }

  /** Everyone active is in the company chat; joining starts "read up to now" (old history is there, but not unread). */
  private async joinCompany(userId: string) {
    await this.companyRoom();
    await this.prisma.chatMember.upsert({
      where: { roomId_userId: { roomId: COMPANY_ROOM_ID, userId } }, create: { roomId: COMPANY_ROOM_ID, userId, lastReadAt: new Date() }, update: {},
    });
  }

  /** Who must hear about something in this room. */
  private async memberIds(room: Pick<ChatRoom, 'id' | 'kind'>): Promise<string[]> {
    if (room.kind === 'COMPANY') return (await this.prisma.user.findMany({ where: { status: 'ACTIVE' }, select: { id: true } })).map((u) => u.id);
    return (await this.prisma.chatMember.findMany({ where: { roomId: room.id }, select: { userId: true } })).map((m) => m.userId);
  }

  /** The room, if this user may see it (member, or anyone for the company chat). */
  private async access(u: AuthUser, roomId: string): Promise<ChatRoom> {
    if (roomId === COMPANY_ROOM_ID) {
      await this.joinCompany(u.id);
      return (await this.prisma.chatRoom.findUnique({ where: { id: roomId } }))!;
    }
    const m = await this.prisma.chatMember.findUnique({ where: { roomId_userId: { roomId, userId: u.id } }, include: { room: true } });
    if (!m) throw notFound('Chat');
    return m.room;
  }

  private async unreadByRoom(userId: string): Promise<Map<string, number>> {
    const rows = await this.prisma.$queryRaw<{ roomId: string; n: bigint }[]>(Prisma.sql`
      SELECT m."roomId" AS "roomId", count(*)::bigint AS n
      FROM chat_messages m JOIN chat_members cm ON cm."roomId" = m."roomId" AND cm."userId" = ${userId}::uuid
      WHERE m."deletedAt" IS NULL AND m."senderId" IS DISTINCT FROM ${userId}::uuid AND (cm."lastReadAt" IS NULL OR m."createdAt" > cm."lastReadAt")
      GROUP BY m."roomId"`);
    return new Map(rows.map((r) => [r.roomId, Number(r.n)]));
  }

  async unread(u: AuthUser) {
    await this.joinCompany(u.id);
    let count = 0;
    for (const n of (await this.unreadByRoom(u.id)).values()) count += n;
    return { count };
  }

  async rooms(u: AuthUser) {
    await this.joinCompany(u.id);
    const mine = await this.prisma.chatMember.findMany({ where: { userId: u.id }, include: { room: true } });
    const ids = mine.map((m) => m.roomId);
    const [unread, peers, counts, lasts] = await Promise.all([
      this.unreadByRoom(u.id),
      this.prisma.chatMember.findMany({
        where: { roomId: { in: mine.filter((m) => m.room.kind === 'DIRECT').map((m) => m.roomId) }, userId: { not: u.id } },
        include: { user: { select: { id: true, fullName: true, role: true, status: true } } },
      }),
      this.prisma.chatMember.groupBy({ by: ['roomId'], where: { roomId: { in: ids.filter((id) => id !== COMPANY_ROOM_ID) } }, _count: { _all: true } }),
      Promise.all(ids.map((roomId) => this.prisma.chatMessage.findFirst({ where: { roomId }, orderBy: { id: 'desc' }, include: { sender: { select: { id: true, fullName: true, role: true } } } }))),
    ]);
    const activeUsers = mine.some((m) => m.roomId === COMPANY_ROOM_ID) ? await this.prisma.user.count({ where: { status: 'ACTIVE' } }) : 0;
    const peerOf = new Map(peers.map((p) => [p.roomId, p]));
    const countOf = new Map(counts.map((c) => [c.roomId, c._count._all]));
    const items = mine.map((m, i) => {
      const peer = peerOf.get(m.roomId);
      const last = lasts[i];
      return {
        id: m.roomId,
        kind: m.room.kind,
        title: m.room.kind === 'DIRECT' ? (peer?.user.fullName ?? null) : m.room.title,
        peer: peer ? { id: peer.user.id, fullName: peer.user.fullName, role: peer.user.role, online: this.presence.isOnline(peer.user.id), lastReadAt: peer.lastReadAt?.toISOString() ?? null } : null,
        memberCount: m.room.kind === 'COMPANY' ? activeUsers : (countOf.get(m.roomId) ?? 0),
        isOwner: m.isOwner,
        unread: unread.get(m.roomId) ?? 0,
        lastMessage: last ? this.dto(last) : null,
        lastMessageAt: (m.room.lastMessageAt ?? m.room.createdAt).toISOString(),
      };
    });
    // the company chat first, then the most recent conversation
    items.sort((a, b) => (a.kind === 'COMPANY' ? -1 : b.kind === 'COMPANY' ? 1 : b.lastMessageAt.localeCompare(a.lastMessageAt)));
    return { items };
  }

  async room(u: AuthUser, roomId: string) {
    const room = await this.access(u, roomId);
    const members = room.kind === 'COMPANY' ? [] : await this.prisma.chatMember.findMany({
      where: { roomId }, include: { user: { select: { id: true, fullName: true, role: true } } }, orderBy: { joinedAt: 'asc' },
    });
    const me = members.find((m) => m.userId === u.id);
    const peer = room.kind === 'DIRECT' ? members.find((m) => m.userId !== u.id) : undefined;
    return {
      id: room.id, kind: room.kind,
      title: room.kind === 'DIRECT' ? (peer?.user.fullName ?? null) : room.title,
      isOwner: me?.isOwner ?? false,
      canManage: room.kind === 'GROUP' && (me?.isOwner === true || isAdmin(u)),
      memberCount: room.kind === 'COMPANY' ? await this.prisma.user.count({ where: { status: 'ACTIVE' } }) : members.length,
      peer: peer ? { id: peer.user.id, fullName: peer.user.fullName, role: peer.user.role, online: this.presence.isOnline(peer.user.id), lastReadAt: peer.lastReadAt?.toISOString() ?? null } : null,
      members: members.map((m) => ({ id: m.user.id, fullName: m.user.fullName, role: m.user.role, isOwner: m.isOwner, online: this.presence.isOnline(m.user.id) })),
    };
  }

  /**
   * Whom this user may start a chat with (owner's rule):
   *  - a WORKER: the administrators and her own manager - never other workers;
   *  - staff: every staff member, plus the workers they may see (all for SUPER_ADMIN / ADMIN, a MANAGER only her own).
   */
  private async reachable(u: AuthUser): Promise<Prisma.UserWhereInput> {
    if (u.role === 'WORKER') {
      const w = u.workerId ? await this.prisma.workerProfile.findUnique({ where: { id: u.workerId }, select: { assignedManagerId: true } }) : null;
      return { OR: [{ role: { in: ['SUPER_ADMIN', 'ADMIN'] } }, ...(w?.assignedManagerId ? [{ id: w.assignedManagerId }] : [])] };
    }
    const scope = u.role === 'SUPER_ADMIN' ? 'all' : scopeFor(u.permissions, 'WORKER');
    const workers: Prisma.UserWhereInput = scope === 'all'
      ? { role: 'WORKER', workerProfile: { deletedAt: null } }
      : scope === 'assigned'
        ? { role: 'WORKER', workerProfile: { deletedAt: null, assignedManagerId: u.id } }
        : { id: { in: [] } };
    return { OR: [{ role: { not: 'WORKER' } }, workers] };
  }

  /** Names and roles only, never phones. */
  async contacts(u: AuthUser, q: z.output<typeof chatContactsQuerySchema>) {
    const rows = await this.prisma.user.findMany({
      where: { AND: [await this.reachable(u), { status: 'ACTIVE', id: { not: u.id }, ...(q.q ? { fullName: { contains: q.q, mode: 'insensitive' as const } } : {}) }] },
      select: { id: true, fullName: true, role: true }, orderBy: { fullName: 'asc' }, take: 300,
    });
    return { items: rows.map((r) => ({ ...r, online: this.presence.isOnline(r.id) })) };
  }

  /** Only people this user may reach (see [reachable]) - checked here, not just hidden in the list. */
  private async activeUsers(u: AuthUser, ids: string[]) {
    const unique = [...new Set(ids)];
    const found = await this.prisma.user.findMany({ where: { AND: [await this.reachable(u), { id: { in: unique }, status: 'ACTIVE' }] }, select: { id: true } });
    if (found.length !== unique.length) throw forbidden('You cannot write to some of these people');
    return unique;
  }

  async direct(u: AuthUser, userId: string) {
    if (userId === u.id) throw validationFailed('Choose someone else');
    await this.activeUsers(u, [userId]);
    const key = directKey(u.id, userId);
    let room = await this.prisma.chatRoom.findUnique({ where: { directKey: key } });
    if (!room) {
      try {
        room = await this.prisma.chatRoom.create({
          data: { kind: 'DIRECT', directKey: key, createdById: u.id, members: { create: [{ userId: u.id }, { userId }] } },
        });
        await this.events.publish('chat.room', { roomId: room.id, userIds: [u.id, userId] });
      } catch (e) {
        if (!(e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002')) throw e;
        room = await this.prisma.chatRoom.findUniqueOrThrow({ where: { directKey: key } }); // both opened it at once
      }
    }
    return this.room(u, room.id);
  }

  async createGroup(u: AuthUser, b: z.output<typeof chatGroupSchema>) {
    const ids = await this.activeUsers(u, b.memberIds.filter((id) => id !== u.id));
    if (!ids.length) throw validationFailed('Add at least one person');
    const now = new Date();
    const room = await this.prisma.chatRoom.create({
      data: {
        kind: 'GROUP', title: b.title, createdById: u.id,
        members: { create: [{ userId: u.id, isOwner: true, lastReadAt: now }, ...ids.map((userId) => ({ userId, lastReadAt: now }))] },
      },
    });
    await this.events.publish('chat.room', { roomId: room.id, userIds: [u.id, ...ids] });
    return this.room(u, room.id);
  }

  async updateGroup(u: AuthUser, roomId: string, b: z.output<typeof chatGroupUpdateSchema>) {
    const room = await this.access(u, roomId);
    if (room.kind !== 'GROUP') throw validationFailed('Only a group can be changed');
    const me = await this.prisma.chatMember.findUnique({ where: { roomId_userId: { roomId, userId: u.id } } });
    if (!me?.isOwner && !isAdmin(u)) throw forbidden('Only the group owner or an administrator can change the group');
    const before = await this.memberIds(room);
    const add = b.addIds?.length ? await this.activeUsers(u, b.addIds) : [];
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      if (b.title) await tx.chatRoom.update({ where: { id: roomId }, data: { title: b.title } });
      if (add.length) await tx.chatMember.createMany({ data: add.map((userId) => ({ roomId, userId, lastReadAt: now })), skipDuplicates: true });
      if (b.removeIds?.length) await tx.chatMember.deleteMany({ where: { roomId, userId: { in: b.removeIds.filter((id) => id !== u.id) } } });
    });
    await this.events.publish('chat.room', { roomId, userIds: [...new Set([...before, ...add])] });
    return this.room(u, roomId);
  }

  /** Leave a group. The owner leaving hands the group to the longest-standing member. */
  async leave(u: AuthUser, roomId: string) {
    const room = await this.access(u, roomId);
    if (room.kind !== 'GROUP') throw validationFailed('Only a group can be left');
    const before = await this.memberIds(room);
    await this.prisma.$transaction(async (tx) => {
      const me = await tx.chatMember.delete({ where: { roomId_userId: { roomId, userId: u.id } } });
      if (me.isOwner) {
        const next = await tx.chatMember.findFirst({ where: { roomId }, orderBy: { joinedAt: 'asc' } });
        if (next) await tx.chatMember.update({ where: { roomId_userId: { roomId, userId: next.userId } }, data: { isOwner: true } });
      }
    });
    await this.events.publish('chat.room', { roomId, userIds: before });
    return { ok: true };
  }

  // ---- messages ---------------------------------------------------------------------------------------------------------
  dto(m: MessageRow) {
    const deleted = !!m.deletedAt;
    const file = !deleted && m.fileId ? this.files.ref(m.fileId) : null;
    return {
      id: m.id, roomId: m.roomId, clientId: m.clientId,
      sender: m.sender ? { id: m.sender.id, fullName: m.sender.fullName, role: m.sender.role } : null,
      kind: deleted ? 'TEXT' : m.kind,
      text: deleted ? null : m.text,
      deleted,
      file: file ? {
        url: file.url, thumbUrl: m.kind === 'IMAGE' ? file.thumbUrl : null, name: m.fileName, size: m.fileSize === null ? null : Number(m.fileSize),
        mimeType: m.mimeType, durationMs: m.durationMs, width: m.width, height: m.height,
      } : null,
      createdAt: m.createdAt.toISOString(),
    };
  }

  async messages(u: AuthUser, roomId: string, q: z.output<typeof chatMessagesQuerySchema>) {
    await this.access(u, roomId);
    const include = { sender: { select: { id: true, fullName: true, role: true } } } as const;
    if (q.after) {
      const rows = await this.prisma.chatMessage.findMany({ where: { roomId, id: { gt: q.after } }, orderBy: { id: 'asc' }, take: q.limit, include });
      return { items: rows.reverse().map((m) => this.dto(m)), hasMore: false };
    }
    const rows = await this.prisma.chatMessage.findMany({
      where: { roomId, ...(q.before ? { id: { lt: q.before } } : {}) }, orderBy: { id: 'desc' }, take: q.limit + 1, include,
    });
    return { items: rows.slice(0, q.limit).map((m) => this.dto(m)), hasMore: rows.length > q.limit }; // newest first
  }

  private async deliver(u: AuthUser, room: ChatRoom, m: MessageRow) {
    const now = m.createdAt;
    await this.prisma.chatRoom.update({ where: { id: room.id }, data: { lastMessageAt: now } });
    await this.prisma.chatMember.updateMany({ where: { roomId: room.id, userId: u.id }, data: { lastReadAt: now } });
    const userIds = await this.memberIds(room);
    await this.events.publish('chat.message', { roomId: room.id, messageId: m.id, senderId: u.id, userIds });
    const preview = m.kind === 'TEXT' ? (m.text ?? '') : m.text ? `${PREVIEW[m.kind]} · ${m.text}` : PREVIEW[m.kind];
    const title = room.kind === 'DIRECT' ? u.fullName : room.kind === 'COMPANY' ? 'Общий чат' : (room.title ?? 'Группа');
    const body = room.kind === 'DIRECT' ? preview : `${u.fullName}: ${preview}`;
    for (const id of userIds) if (id !== u.id) void this.push.send(id, { id: m.id, title, body: body.slice(0, 300), link: `/chat/${room.id}`, kind: 'chat' });
  }

  private async existing(u: AuthUser, clientId: string | undefined) {
    if (!clientId) return null;
    return this.prisma.chatMessage.findUnique({ where: { senderId_clientId: { senderId: u.id, clientId } }, include: { sender: { select: { id: true, fullName: true, role: true } } } });
  }

  async sendText(u: AuthUser, roomId: string, b: z.output<typeof chatTextSchema>) {
    const room = await this.access(u, roomId);
    const again = await this.existing(u, b.clientId);
    if (again) return this.dto(again); // a retried send (bad connection): the same message, not a second one
    const m = await this.prisma.chatMessage.create({
      data: { roomId, senderId: u.id, kind: 'TEXT', text: b.text, clientId: b.clientId },
      include: { sender: { select: { id: true, fullName: true, role: true } } },
    });
    await this.deliver(u, room, m);
    return this.dto(m);
  }

  async sendFile(u: AuthUser, roomId: string, b: z.output<typeof chatFileFieldsSchema>, file: { buffer: Buffer; originalName?: string; mimetype?: string }) {
    const room = await this.access(u, roomId);
    const again = await this.existing(u, b.clientId);
    if (again) return this.dto(again);
    if (file.buffer.length > CHAT_MAX_FILE_BYTES) throw fileRejected('The file is larger than 50 MB');
    const declared = b.kind ?? (file.mimetype?.startsWith('image/') ? 'IMAGE' : file.mimetype?.startsWith('video/') ? 'VIDEO' : file.mimetype?.startsWith('audio/') ? 'AUDIO' : 'FILE');
    const name = file.originalName?.slice(0, 200);
    let kind: ChatMessageKind = 'FILE';
    let stored: { id: string; mimeType: string; width?: number | null; height?: number | null } | null = null;

    if (declared === 'IMAGE') {
      try {
        const img = await this.files.prepareImage(file.buffer, CHAT_MAX_FILE_BYTES);
        const a = await this.files.store({ bucket: 'chat', image: img, uploadedById: u.id, originalName: name });
        stored = { id: a.id, mimeType: a.mimeType, width: a.width, height: a.height };
        kind = 'IMAGE';
      } catch (e) {
        if (!(e instanceof AppError)) throw e; // not a real photo: sent as a plain file below
      }
    }
    if (!stored) {
      const s = sniff(file.buffer);
      if (s && (declared === 'VIDEO' || declared === 'VOICE' || declared === 'AUDIO')) {
        const audio = declared === 'VOICE' || declared === 'AUDIO';
        if (audio && s.family !== 'video') {
          kind = declared;
          const mime = s.mime === 'video/mp4' ? 'audio/mp4' : s.mime === 'video/webm' ? 'audio/webm' : s.mime;
          const ext = s.ext === 'mp4' ? 'm4a' : s.ext;
          const a = await this.files.storeRaw({ bucket: 'chat', buffer: file.buffer, mimeType: mime, ext, uploadedById: u.id, originalName: name });
          stored = { id: a.id, mimeType: mime };
        } else if (!audio && s.family !== 'audio') {
          kind = 'VIDEO';
          const a = await this.files.storeRaw({ bucket: 'chat', buffer: file.buffer, mimeType: s.mime, ext: s.ext, uploadedById: u.id, originalName: name });
          stored = { id: a.id, mimeType: s.mime };
        }
      }
    }
    if (!stored) {
      // a document (or anything unrecognised): kept byte-for-byte, always downloaded, never opened in the browser
      const a = await this.files.storeRaw({ bucket: 'chat', buffer: file.buffer, mimeType: 'application/octet-stream', ext: safeExt(name), uploadedById: u.id, originalName: name });
      stored = { id: a.id, mimeType: 'application/octet-stream' };
      kind = 'FILE';
    }
    const m = await this.prisma.chatMessage.create({
      data: {
        roomId, senderId: u.id, kind, text: b.text || null, clientId: b.clientId, fileId: stored.id, fileName: name ?? null,
        fileSize: BigInt(file.buffer.length), mimeType: stored.mimeType, durationMs: b.durationMs ?? null, width: stored.width ?? null, height: stored.height ?? null,
      },
      include: { sender: { select: { id: true, fullName: true, role: true } } },
    });
    await this.deliver(u, room, m);
    return this.dto(m);
  }

  async read(u: AuthUser, roomId: string) {
    const room = await this.access(u, roomId);
    await this.prisma.chatMember.updateMany({ where: { roomId, userId: u.id }, data: { lastReadAt: new Date() } });
    // a direct chat shows «прочитано» to the other person; everywhere else only my other devices care
    const userIds = room.kind === 'DIRECT' ? await this.memberIds(room) : [u.id];
    await this.events.publish('chat.read', { roomId, userId: u.id, userIds });
    return { ok: true };
  }

  /** Your own message, or any message for SUPER_ADMIN / ADMIN. The row stays («Сообщение удалено»). */
  async deleteMessage(u: AuthUser, id: string) {
    const m = await this.prisma.chatMessage.findUnique({ where: { id } });
    if (!m) throw notFound('Message');
    const room = await this.access(u, m.roomId);
    if (m.senderId !== u.id && !isAdmin(u)) throw forbidden('You can delete only your own messages');
    if (!m.deletedAt) await this.prisma.chatMessage.update({ where: { id }, data: { deletedAt: new Date(), text: null } });
    await this.events.publish('chat.message_deleted', { roomId: m.roomId, messageId: id, userIds: await this.memberIds(room) });
    return { ok: true };
  }
}

@ApiTags('chat')
@ApiBearerAuth()
@Controller('chat')
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @Authenticated() @Get('rooms')
  rooms(@CurrentUser() u: AuthUser) { return this.chat.rooms(u); }

  @Authenticated() @Get('unread')
  unread(@CurrentUser() u: AuthUser) { return this.chat.unread(u); }

  @Authenticated() @Get('contacts')
  contacts(@CurrentUser() u: AuthUser, @ZodQuery(chatContactsQuerySchema) q: z.output<typeof chatContactsQuerySchema>) { return this.chat.contacts(u, q); }

  @Authenticated() @Post('direct') @HttpCode(200) @ApiZodBody(chatDirectSchema)
  direct(@CurrentUser() u: AuthUser, @ZodBody(chatDirectSchema) b: z.output<typeof chatDirectSchema>) { return this.chat.direct(u, b.userId); }

  @Authenticated() @Post('groups') @ApiZodBody(chatGroupSchema)
  createGroup(@CurrentUser() u: AuthUser, @ZodBody(chatGroupSchema) b: z.output<typeof chatGroupSchema>) { return this.chat.createGroup(u, b); }

  @Authenticated() @Get('rooms/:id')
  room(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.chat.room(u, id); }

  @Authenticated() @Patch('rooms/:id') @ApiZodBody(chatGroupUpdateSchema)
  update(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(chatGroupUpdateSchema) b: z.output<typeof chatGroupUpdateSchema>) { return this.chat.updateGroup(u, id, b); }

  @Authenticated() @Post('rooms/:id/leave') @HttpCode(200)
  leave(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.chat.leave(u, id); }

  @Authenticated() @Get('rooms/:id/messages')
  messages(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodQuery(chatMessagesQuerySchema) q: z.output<typeof chatMessagesQuerySchema>) {
    return this.chat.messages(u, id, q);
  }

  @Authenticated() @Post('rooms/:id/messages') @ApiZodBody(chatTextSchema)
  send(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(chatTextSchema) b: z.output<typeof chatTextSchema>) { return this.chat.sendText(u, id, b); }

  @Authenticated() @Post('rooms/:id/files') @ApiConsumes('multipart/form-data')
  @ApiBody({ schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' }, kind: { type: 'string' }, text: { type: 'string' }, durationMs: { type: 'number' } } } })
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: CHAT_MAX_FILE_BYTES } }))
  sendFile(
    @CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string,
    @ZodBody(chatFileFieldsSchema) b: z.output<typeof chatFileFieldsSchema>, @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!file) throw fileRejected('Attach the file as multipart field "file"');
    return this.chat.sendFile(u, id, b, { buffer: file.buffer, originalName: file.originalname, mimetype: file.mimetype });
  }

  @Authenticated() @Post('rooms/:id/read') @HttpCode(200)
  read(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.chat.read(u, id); }

  @Authenticated() @Delete('messages/:id') @HttpCode(200)
  remove(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.chat.deleteMessage(u, id); }
}

@Module({ imports: [PresenceModule], controllers: [ChatController], providers: [ChatService] })
export class ChatModule {}

