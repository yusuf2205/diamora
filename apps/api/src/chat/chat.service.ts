import { Controller, Delete, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Patch, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { ConnectedSocket, MessageBody, SubscribeMessage, WebSocketGateway } from '@nestjs/websockets';
import { Throttle } from '@nestjs/throttler';
import type { Socket } from 'socket.io';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { Prisma, type ChatAudience, type ChatMember, type ChatMessage, type ChatRoom } from '@diamoraa/database';
import {
  CHAT_MAX_FILE_BYTES, chatChannelSchema, chatContactsQuerySchema, chatMediaQuerySchema, chatDirectSchema, chatEditSchema, chatFileFieldsSchema, chatForwardSchema, chatGroupSchema,
  chatGroupUpdateSchema, chatMemberPrefsSchema, chatMessagesQuerySchema, chatPinSchema, chatReactSchema, chatSearchSchema, chatTextSchema, scopeFor,
  type ChatMessageKind,
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
import { AuditService } from '../audit/audit.service';

/** The one chat of everyone: a fixed id, created on first use. */
export const COMPANY_ROOM_ID = '00000000-0000-4000-8000-00000000c4a7';

const PREVIEW: Record<Exclude<ChatMessageKind, 'TEXT'>, string> = {
  IMAGE: '📷 Фото', VIDEO: '🎬 Видео', VOICE: '🎤 Голосовое сообщение', AUDIO: '🎵 Аудио', FILE: '📎 Файл',
};
const isAdmin = (u: AuthUser) => u.role === 'SUPER_ADMIN' || u.role === 'ADMIN';
const directKey = (a: string, b: string) => [a, b].sort().join(':');

type Sender = { id: string; fullName: string; role: string } | null;
type MessageRow = ChatMessage & {
  sender: Sender;
  replyTo?: (ChatMessage & { sender: Sender }) | null;
  reactions?: { userId: string; emoji: string }[];
};
const SENDER = { select: { id: true, fullName: true, role: true } } as const;
/** everything a message row needs to be shown (who, what it answers, reactions) */
const MSG_INCLUDE = { sender: SENDER, replyTo: { include: { sender: SENDER } }, reactions: { select: { userId: true, emoji: true } } } as const;
/** a sent message can be edited for 48 hours */
const EDIT_WINDOW_MS = 48 * 3600_000;
const FAR_FUTURE = new Date('9999-01-01T00:00:00Z');

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
    private readonly audit: AuditService,
  ) {}

  // ---- channels: an audience reads, admins post --------------------------------------------------------------------------
  private audienceWhere(a: ChatAudience): Prisma.UserWhereInput | null {
    if (a === 'ALL') return { status: 'ACTIVE' };
    if (a === 'STAFF') return { status: 'ACTIVE', role: { not: 'WORKER' } };
    if (a === 'WORKERS') return { status: 'ACTIVE', role: 'WORKER' };
    return null; // CUSTOM: the members added by hand
  }
  private inAudience(u: AuthUser, a: ChatAudience) {
    return a === 'ALL' || (a === 'STAFF' && u.role !== 'WORKER') || (a === 'WORKERS' && u.role === 'WORKER');
  }
  /** Channels for «everyone» / «staff» / «workers» are joined automatically (read up to now), like the company chat. */
  private async joinAudienceChannels(u: AuthUser) {
    const audiences: ChatAudience[] = u.role === 'WORKER' ? ['ALL', 'WORKERS'] : ['ALL', 'STAFF'];
    const chans = await this.prisma.chatRoom.findMany({ where: { kind: 'CHANNEL', audience: { in: audiences }, members: { none: { userId: u.id } } }, select: { id: true, createdAt: true } });
    if (!chans.length) return;
    const since = await this.joinedAt(u);
    await this.prisma.chatMember.createMany({ data: chans.map((c) => ({ roomId: c.id, userId: u.id, lastReadAt: c.createdAt > since ? c.createdAt : since })), skipDuplicates: true });
  }
  /** announcements posted since this person joined the company are unread for them (older ones are just history) */
  private async joinedAt(u: AuthUser): Promise<Date> {
    return (await this.prisma.user.findUnique({ where: { id: u.id }, select: { createdAt: true } }))?.createdAt ?? new Date();
  }

  /** Who may post: anyone in a direct / company chat; in a group everyone unless «only admins write»; in a channel only its admins. */
  private canWrite(u: AuthUser, room: Pick<ChatRoom, 'kind' | 'onlyAdminsWrite'>, me: Pick<ChatMember, 'isOwner' | 'isAdmin'> | null) {
    const roomAdmin = !!me && (me.isOwner || me.isAdmin);
    if (room.kind === 'CHANNEL') return roomAdmin || u.role === 'SUPER_ADMIN';
    if (room.kind === 'GROUP' && room.onlyAdminsWrite) return roomAdmin || isAdmin(u);
    return true;
  }
  private canManage(u: AuthUser, room: Pick<ChatRoom, 'kind'>, me: Pick<ChatMember, 'isOwner' | 'isAdmin'> | null) {
    return (room.kind === 'GROUP' || room.kind === 'CHANNEL') && (!!me?.isOwner || !!me?.isAdmin || isAdmin(u));
  }
  private async me(u: AuthUser, roomId: string) {
    return this.prisma.chatMember.findUnique({ where: { roomId_userId: { roomId, userId: u.id } } });
  }
  /** The room, if this user may post there. */
  private async writable(u: AuthUser, roomId: string): Promise<ChatRoom> {
    const room = await this.access(u, roomId);
    if (!this.canWrite(u, room, await this.me(u, roomId))) throw forbidden('Only the admins write in this chat');
    return room;
  }

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
  private async memberIds(room: Pick<ChatRoom, 'id' | 'kind'> & { audience?: ChatAudience }): Promise<string[]> {
    if (room.kind === 'COMPANY') return (await this.prisma.user.findMany({ where: { status: 'ACTIVE' }, select: { id: true } })).map((u) => u.id);
    const aud = room.kind === 'CHANNEL' ? this.audienceWhere((room as ChatRoom).audience ?? 'CUSTOM') : null;
    if (aud) return (await this.prisma.user.findMany({ where: aud, select: { id: true } })).map((u) => u.id);
    return (await this.prisma.chatMember.findMany({ where: { roomId: room.id }, select: { userId: true } })).map((m) => m.userId);
  }

  /** The room, if this user may see it (member, or anyone for the company chat). */
  private async access(u: AuthUser, roomId: string): Promise<ChatRoom> {
    if (roomId === COMPANY_ROOM_ID) {
      await this.joinCompany(u.id);
      return (await this.prisma.chatRoom.findUnique({ where: { id: roomId } }))!;
    }
    const m = await this.prisma.chatMember.findUnique({ where: { roomId_userId: { roomId, userId: u.id } }, include: { room: true } });
    if (m) return m.room;
    // an audience channel this person belongs to by role: joined on first open
    const room = await this.prisma.chatRoom.findUnique({ where: { id: roomId } });
    if (room?.kind === 'CHANNEL' && room.audience !== 'CUSTOM' && this.inAudience(u, room.audience)) {
      const since = await this.joinedAt(u);
      await this.prisma.chatMember.upsert({ where: { roomId_userId: { roomId, userId: u.id } }, create: { roomId, userId: u.id, lastReadAt: room.createdAt > since ? room.createdAt : since }, update: {} });
      return room;
    }
    throw notFound('Chat');
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
    await this.joinAudienceChannels(u);
    let count = 0;
    for (const n of (await this.unreadByRoom(u.id)).values()) count += n;
    return { count };
  }

  async rooms(u: AuthUser) {
    await this.joinCompany(u.id);
    await this.joinAudienceChannels(u);
    const mine = await this.prisma.chatMember.findMany({ where: { userId: u.id }, include: { room: true } });
    const ids = mine.map((m) => m.roomId);
    const [unread, peers, counts, lasts] = await Promise.all([
      this.unreadByRoom(u.id),
      this.prisma.chatMember.findMany({
        where: { roomId: { in: mine.filter((m) => m.room.kind === 'DIRECT').map((m) => m.roomId) }, userId: { not: u.id } },
        include: { user: { select: { id: true, fullName: true, role: true, status: true, lastSeenAt: true } } },
      }),
      this.prisma.chatMember.groupBy({ by: ['roomId'], where: { roomId: { in: ids.filter((id) => id !== COMPANY_ROOM_ID) } }, _count: { _all: true } }),
      Promise.all(ids.map((roomId) => this.prisma.chatMessage.findFirst({ where: { roomId }, orderBy: { id: 'desc' }, include: MSG_INCLUDE }))),
    ]);
    const activeUsers = mine.some((m) => m.roomId === COMPANY_ROOM_ID) ? await this.prisma.user.count({ where: { status: 'ACTIVE' } }) : 0;
    const peerOf = new Map(peers.map((p) => [p.roomId, p]));
    const countOf = new Map(counts.map((c) => [c.roomId, c._count._all]));
    const audienceCount = new Map<ChatAudience, number>();
    for (const a of new Set(mine.filter((m) => m.room.kind === 'CHANNEL' && m.room.audience !== 'CUSTOM').map((m) => m.room.audience))) {
      audienceCount.set(a, await this.prisma.user.count({ where: this.audienceWhere(a)! }));
    }
    const items = mine.map((m, i) => {
      const peer = peerOf.get(m.roomId);
      const last = lasts[i];
      return {
        id: m.roomId,
        kind: m.room.kind,
        title: m.room.kind === 'DIRECT' ? (peer?.user.fullName ?? null) : m.room.title,
        peer: peer ? this.person(peer.user, peer.lastReadAt) : null,
        memberCount: m.room.kind === 'COMPANY' ? activeUsers : m.room.kind === 'CHANNEL' && m.room.audience !== 'CUSTOM' ? (audienceCount.get(m.room.audience) ?? 0) : (countOf.get(m.roomId) ?? 0),
        isOwner: m.isOwner,
        photo: m.room.photoFileId ? this.files.ref(m.room.photoFileId)?.thumbUrl ?? null : null,
        pinned: !!m.pinnedAt,
        pinnedAt: m.pinnedAt?.toISOString() ?? null,
        muted: !!m.mutedUntil && m.mutedUntil > new Date(),
        unread: unread.get(m.roomId) ?? 0,
        lastMessage: last ? this.dto(last, u.id) : null,
        lastMessageAt: (m.room.lastMessageAt ?? m.room.createdAt).toISOString(),
      };
    });
    // my pinned chats first (in the order I pinned them), then the company chat, then the most recent conversation
    const rank = (x: (typeof items)[number]) => (x.pinnedAt ? 0 : x.kind === 'COMPANY' ? 1 : 2);
    items.sort((a, b) => rank(a) - rank(b) || (a.pinnedAt && b.pinnedAt ? a.pinnedAt.localeCompare(b.pinnedAt) : b.lastMessageAt.localeCompare(a.lastMessageAt)));
    return { items };
  }

  async room(u: AuthUser, roomId: string) {
    const room = await this.access(u, roomId);
    // an audience channel lists only its admins (everyone of that audience reads it)
    const audienceChannel = room.kind === 'CHANNEL' && room.audience !== 'CUSTOM';
    const members = room.kind === 'COMPANY' ? [] : await this.prisma.chatMember.findMany({
      where: { roomId, ...(audienceChannel ? { OR: [{ isOwner: true }, { isAdmin: true }] } : {}) },
      include: { user: { select: { id: true, fullName: true, role: true, lastSeenAt: true } } }, orderBy: { joinedAt: 'asc' },
    });
    const me = members.find((m) => m.userId === u.id) ?? (await this.prisma.chatMember.findUnique({ where: { roomId_userId: { roomId, userId: u.id } } }));
    const pinned = room.pinnedMessageId ? await this.prisma.chatMessage.findFirst({ where: { id: room.pinnedMessageId, roomId, deletedAt: null }, include: MSG_INCLUDE }) : null;
    const peer = room.kind === 'DIRECT' ? members.find((m) => m.userId !== u.id) : undefined;
    return {
      id: room.id, kind: room.kind,
      title: room.kind === 'DIRECT' ? (peer?.user.fullName ?? null) : room.title,
      isOwner: me?.isOwner ?? false,
      isAdmin: !!me?.isAdmin,
      canManage: this.canManage(u, room, me ?? null),
      canEditAdmins: (room.kind === 'GROUP' || room.kind === 'CHANNEL') && (!!me?.isOwner || isAdmin(u)),
      canWrite: this.canWrite(u, room, me ?? null),
      canPin: this.canPin(u, room, me ?? null),
      description: room.description,
      photo: room.photoFileId ? this.files.ref(room.photoFileId) : null,
      audience: room.kind === 'CHANNEL' ? room.audience : null,
      onlyAdminsWrite: room.onlyAdminsWrite,
      pinned: !!me?.pinnedAt,
      muted: !!me?.mutedUntil && me.mutedUntil > new Date(),
      pinnedMessage: pinned ? this.dto(pinned, u.id) : null,
      memberCount: room.kind === 'COMPANY'
        ? await this.prisma.user.count({ where: { status: 'ACTIVE' } })
        : audienceChannel ? await this.prisma.user.count({ where: this.audienceWhere(room.audience)! }) : members.length,
      peer: peer ? this.person(peer.user, peer.lastReadAt) : null,
      members: members.map((m) => ({ ...this.person(m.user, null), isOwner: m.isOwner, isAdmin: m.isAdmin })),
    };
  }

  /** online now, or when last seen («был(а) в сети …») */
  private person(user: { id: string; fullName: string; role: string; lastSeenAt?: Date | null }, lastReadAt: Date | null) {
    const online = this.presence.isOnline(user.id);
    return { id: user.id, fullName: user.fullName, role: user.role, online, lastSeenAt: online ? null : (user.lastSeenAt?.toISOString() ?? null), lastReadAt: lastReadAt?.toISOString() ?? null };
  }

  /** the pinned message: anyone in a direct chat, the owner / an administrator in a group, administrators in the company chat */
  private canPin(u: AuthUser, room: Pick<ChatRoom, 'kind'>, me: Pick<ChatMember, 'isOwner' | 'isAdmin'> | null) {
    return room.kind === 'DIRECT' || isAdmin(u) || ((room.kind === 'GROUP' || room.kind === 'CHANNEL') && (!!me?.isOwner || !!me?.isAdmin));
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
      select: { id: true, fullName: true, role: true, lastSeenAt: true }, orderBy: { fullName: 'asc' }, take: 300,
    });
    return { items: rows.map((r) => this.person(r, null)) };
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

  /** An announcement channel (SUPER_ADMIN / ADMIN): its admins post, the audience reads. Audited. */
  async createChannel(u: AuthUser, b: z.output<typeof chatChannelSchema>) {
    if (!isAdmin(u)) throw forbidden('Only administrators create channels');
    const ids = b.audience === 'CUSTOM' ? await this.activeUsers(u, b.memberIds.filter((id) => id !== u.id)) : [];
    const now = new Date();
    const room = await this.prisma.$transaction(async (tx) => {
      const room = await tx.chatRoom.create({
        data: {
          kind: 'CHANNEL', title: b.title, description: b.description || null, audience: b.audience, createdById: u.id,
          members: { create: [{ userId: u.id, isOwner: true, isAdmin: true, lastReadAt: now }, ...ids.map((userId) => ({ userId, lastReadAt: now }))] },
        },
      });
      await this.audit.record({ action: 'chat.channel_created', entity: 'ChatRoom', entityId: room.id, after: { title: b.title, audience: b.audience, members: ids.length } }, tx);
      return room;
    });
    await this.events.publish('chat.room', { roomId: room.id, userIds: await this.memberIds(room) });
    return this.room(u, room.id);
  }

  /** Group or channel settings. Members / title / description / «only admins write»: its admins; who is admin: the owner. */
  async updateGroup(u: AuthUser, roomId: string, b: z.output<typeof chatGroupUpdateSchema>) {
    const room = await this.access(u, roomId);
    if (room.kind !== 'GROUP' && room.kind !== 'CHANNEL') throw validationFailed('Only a group or a channel can be changed');
    const me = await this.me(u, roomId);
    if (!this.canManage(u, room, me)) throw forbidden('Only the owner or the admins of this chat can change it');
    const changesAdmins = !!(b.adminIds?.length || b.unadminIds?.length);
    if (changesAdmins && !me?.isOwner && !isAdmin(u)) throw forbidden('Only the owner chooses the admins');
    if ((b.addIds?.length || b.removeIds?.length) && room.kind === 'CHANNEL' && room.audience !== 'CUSTOM') throw validationFailed('This channel is read by everyone of its audience');
    const before = await this.memberIds(room);
    const add = b.addIds?.length ? await this.activeUsers(u, b.addIds) : [];
    const newAdmins = b.adminIds?.length ? await this.activeUsers(u, b.adminIds) : [];
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      const data: Prisma.ChatRoomUpdateInput = {};
      if (b.title) data.title = b.title;
      if (b.description !== undefined) data.description = b.description || null;
      if (b.onlyAdminsWrite !== undefined && room.kind === 'GROUP') data.onlyAdminsWrite = b.onlyAdminsWrite;
      if (Object.keys(data).length) await tx.chatRoom.update({ where: { id: roomId }, data });
      if (add.length) await tx.chatMember.createMany({ data: add.map((userId) => ({ roomId, userId, lastReadAt: now })), skipDuplicates: true });
      if (b.removeIds?.length) await tx.chatMember.deleteMany({ where: { roomId, isOwner: false, userId: { in: b.removeIds.filter((id) => id !== u.id) } } });
      for (const userId of newAdmins) {
        await tx.chatMember.upsert({ where: { roomId_userId: { roomId, userId } }, create: { roomId, userId, isAdmin: true, lastReadAt: now }, update: { isAdmin: true } });
      }
      if (b.unadminIds?.length) await tx.chatMember.updateMany({ where: { roomId, isOwner: false, userId: { in: b.unadminIds } }, data: { isAdmin: false } });
      if (add.length || b.removeIds?.length || changesAdmins || room.kind === 'CHANNEL') {
        await this.audit.record({
          action: 'chat.room_changed', entity: 'ChatRoom', entityId: roomId,
          after: { title: b.title, description: b.description, added: add.length, removed: b.removeIds?.length ?? 0, admins: newAdmins.length, unadmins: b.unadminIds?.length ?? 0, onlyAdminsWrite: b.onlyAdminsWrite },
        }, tx);
      }
    });
    await this.events.publish('chat.room', { roomId, userIds: [...new Set([...before, ...add, ...newAdmins])] });
    return this.room(u, roomId);
  }

  /** A group / channel photo (its admins): a real image, resized, EXIF stripped. */
  async setPhoto(u: AuthUser, roomId: string, buffer: Buffer) {
    const room = await this.access(u, roomId);
    if (!this.canManage(u, room, await this.me(u, roomId))) throw forbidden('Only the admins of this chat can change its photo');
    const a = await this.files.uploadImage({ bucket: 'chat', buffer, uploadedById: u.id, originalName: 'photo.jpg' });
    await this.prisma.chatRoom.update({ where: { id: roomId }, data: { photoFileId: a.id } });
    await this.events.publish('chat.room', { roomId, userIds: await this.memberIds(room) });
    return this.room(u, roomId);
  }

  /** «Медиа», «Файлы», «Голосовые», «Ссылки» of a chat (newest first). */
  async media(u: AuthUser, roomId: string, q: z.output<typeof chatMediaQuerySchema>) {
    await this.access(u, roomId);
    const where: Prisma.ChatMessageWhereInput = { roomId, deletedAt: null, ...(q.before ? { id: { lt: q.before } } : {}) };
    if (q.kind === 'media') where.kind = { in: ['IMAGE', 'VIDEO'] };
    if (q.kind === 'files') where.kind = { in: ['FILE', 'AUDIO'] };
    if (q.kind === 'voice') where.kind = 'VOICE';
    if (q.kind === 'links') where.OR = [{ text: { contains: 'http', mode: 'insensitive' } }, { text: { contains: 'www.', mode: 'insensitive' } }];
    const rows = await this.prisma.chatMessage.findMany({ where, orderBy: { id: 'desc' }, take: q.limit + 1, include: MSG_INCLUDE });
    return { items: rows.slice(0, q.limit).map((m) => this.dto(m, u.id)), hasMore: rows.length > q.limit };
  }

  /** Leave a group. The owner leaving hands the group to the longest-standing member. */
  async leave(u: AuthUser, roomId: string) {
    const room = await this.access(u, roomId);
    if (room.kind !== 'GROUP' && !(room.kind === 'CHANNEL' && room.audience === 'CUSTOM')) throw validationFailed('This chat cannot be left (turn its notifications off instead)');
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
  dto(m: MessageRow, meId?: string) {
    const deleted = !!m.deletedAt;
    const file = !deleted && m.fileId ? this.files.ref(m.fileId) : null;
    const counts = new Map<string, { emoji: string; count: number; mine: boolean }>();
    for (const x of deleted ? [] : (m.reactions ?? [])) {
      const c = counts.get(x.emoji) ?? { emoji: x.emoji, count: 0, mine: false };
      c.count++;
      if (x.userId === meId) c.mine = true;
      counts.set(x.emoji, c);
    }
    const reply = m.replyTo;
    return {
      id: m.id, roomId: m.roomId, clientId: m.clientId,
      replyTo: reply ? { id: reply.id, sender: reply.sender?.fullName ?? null, preview: reply.deletedAt ? null : this.preview(reply), deleted: !!reply.deletedAt } : null,
      forwardedFrom: deleted ? null : m.forwardedFrom,
      editedAt: m.editedAt?.toISOString() ?? null,
      reactions: [...counts.values()].sort((a, b) => b.count - a.count),
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

  private preview(m: Pick<ChatMessage, 'kind' | 'text'>) {
    return m.kind === 'TEXT' ? (m.text ?? '') : m.text ? `${PREVIEW[m.kind]} · ${m.text}` : PREVIEW[m.kind];
  }

  async messages(u: AuthUser, roomId: string, q: z.output<typeof chatMessagesQuerySchema>) {
    await this.access(u, roomId);
    const include = MSG_INCLUDE;
    if (q.after) {
      const rows = await this.prisma.chatMessage.findMany({ where: { roomId, id: { gt: q.after } }, orderBy: { id: 'asc' }, take: q.limit, include });
      return { items: rows.reverse().map((m) => this.dto(m, u.id)), hasMore: false };
    }
    const rows = await this.prisma.chatMessage.findMany({
      where: { roomId, ...(q.before ? { id: { lt: q.before } } : {}) }, orderBy: { id: 'desc' }, take: q.limit + 1, include,
    });
    return { items: rows.slice(0, q.limit).map((m) => this.dto(m, u.id)), hasMore: rows.length > q.limit }; // newest first
  }

  private async deliver(u: AuthUser, room: ChatRoom, m: MessageRow) {
    const now = m.createdAt;
    await this.prisma.chatRoom.update({ where: { id: room.id }, data: { lastMessageAt: now } });
    await this.prisma.chatMember.updateMany({ where: { roomId: room.id, userId: u.id }, data: { lastReadAt: now } });
    const userIds = await this.memberIds(room);
    await this.events.publish('chat.message', { roomId: room.id, messageId: m.id, senderId: u.id, userIds });
    const preview = this.preview(m);
    const muted = new Set((await this.prisma.chatMember.findMany({ where: { roomId: room.id, mutedUntil: { gt: new Date() } }, select: { userId: true } })).map((x) => x.userId));
    const title = room.kind === 'DIRECT' ? u.fullName : room.kind === 'COMPANY' ? 'Общий чат' : (room.title ?? 'Группа');
    const body = room.kind === 'DIRECT' ? preview : `${u.fullName}: ${preview}`;
    for (const id of userIds) if (id !== u.id && !muted.has(id)) void this.push.send(id, { id: m.id, title, body: body.slice(0, 300), link: `/chat/${room.id}`, kind: 'chat' });
  }

  private async existing(u: AuthUser, clientId: string | undefined) {
    if (!clientId) return null;
    return this.prisma.chatMessage.findUnique({ where: { senderId_clientId: { senderId: u.id, clientId } }, include: MSG_INCLUDE });
  }

  async sendText(u: AuthUser, roomId: string, b: z.output<typeof chatTextSchema>) {
    const room = await this.writable(u, roomId);
    const again = await this.existing(u, b.clientId);
    if (again) return this.dto(again, u.id); // a retried send (bad connection): the same message, not a second one
    const replyToId = await this.replyTarget(roomId, b.replyToId);
    const m = await this.prisma.chatMessage.create({
      data: { roomId, senderId: u.id, kind: 'TEXT', text: b.text, clientId: b.clientId, replyToId },
      include: MSG_INCLUDE,
    });
    await this.deliver(u, room, m);
    return this.dto(m, u.id);
  }

  async sendFile(u: AuthUser, roomId: string, b: z.output<typeof chatFileFieldsSchema>, file: { buffer: Buffer; originalName?: string; mimetype?: string }) {
    const room = await this.writable(u, roomId);
    const again = await this.existing(u, b.clientId);
    if (again) return this.dto(again, u.id);
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
        roomId, senderId: u.id, kind, text: b.text || null, clientId: b.clientId, fileId: stored.id, fileName: name ?? null, replyToId: await this.replyTarget(roomId, b.replyToId),
        fileSize: BigInt(file.buffer.length), mimeType: stored.mimeType, durationMs: b.durationMs ?? null, width: stored.width ?? null, height: stored.height ?? null,
      },
      include: MSG_INCLUDE,
    });
    await this.deliver(u, room, m);
    return this.dto(m, u.id);
  }

  /** a reply must point at a message of the same chat */
  private async replyTarget(roomId: string, id?: string) {
    if (!id) return null;
    const m = await this.prisma.chatMessage.findFirst({ where: { id, roomId }, select: { id: true } });
    if (!m) throw validationFailed('The message you reply to is not in this chat');
    return m.id;
  }

  private async updated(room: Pick<ChatRoom, 'id' | 'kind'>, messageId: string) {
    await this.events.publish('chat.message_updated', { roomId: room.id, messageId, userIds: await this.memberIds(room) });
  }

  /** Your own text (or caption), for 48 hours; the message says «изменено». */
  async edit(u: AuthUser, id: string, b: z.output<typeof chatEditSchema>) {
    const m = await this.prisma.chatMessage.findUnique({ where: { id } });
    if (!m) throw notFound('Message');
    const room = await this.access(u, m.roomId);
    if (m.senderId !== u.id) throw forbidden('You can edit only your own messages');
    if (m.deletedAt) throw validationFailed('The message was deleted');
    if (m.forwardedFrom) throw validationFailed('A forwarded message cannot be edited');
    if (Date.now() - m.createdAt.getTime() > EDIT_WINDOW_MS) throw validationFailed('A message can be edited for 48 hours');
    const row = await this.prisma.chatMessage.update({ where: { id }, data: { text: b.text, editedAt: new Date() }, include: MSG_INCLUDE });
    await this.updated(room, id);
    return this.dto(row, u.id);
  }

  /** One reaction per person: the same emoji again takes it back, another one replaces it. */
  async react(u: AuthUser, id: string, emoji: string) {
    const m = await this.prisma.chatMessage.findUnique({ where: { id } });
    if (!m || m.deletedAt) throw notFound('Message');
    const room = await this.access(u, m.roomId);
    const mine = await this.prisma.chatReaction.findUnique({ where: { messageId_userId: { messageId: id, userId: u.id } } });
    if (mine?.emoji === emoji) await this.prisma.chatReaction.delete({ where: { messageId_userId: { messageId: id, userId: u.id } } });
    else await this.prisma.chatReaction.upsert({ where: { messageId_userId: { messageId: id, userId: u.id } }, create: { messageId: id, userId: u.id, emoji }, update: { emoji, createdAt: new Date() } });
    await this.updated(room, id);
    return this.dto(await this.prisma.chatMessage.findUniqueOrThrow({ where: { id }, include: MSG_INCLUDE }), u.id);
  }

  /** Copies of a message (its file is shared, not copied) into chats I am in; «Переслано от …». */
  async forward(u: AuthUser, id: string, roomIds: string[]) {
    const src = await this.prisma.chatMessage.findUnique({ where: { id }, include: { sender: SENDER } });
    if (!src || src.deletedAt) throw notFound('Message');
    await this.access(u, src.roomId); // I may read the original
    const targets = [];
    for (const roomId of [...new Set(roomIds)]) targets.push(await this.writable(u, roomId)); // and may write where it goes
    const out = [];
    for (const room of targets) {
      const m = await this.prisma.chatMessage.create({
        data: {
          roomId: room.id, senderId: u.id, kind: src.kind, text: src.text, fileId: src.fileId, fileName: src.fileName, fileSize: src.fileSize, mimeType: src.mimeType,
          durationMs: src.durationMs, width: src.width, height: src.height, forwardedFrom: src.forwardedFrom ?? src.sender?.fullName ?? null,
        },
        include: MSG_INCLUDE,
      });
      await this.deliver(u, room, m);
      out.push(this.dto(m, u.id));
    }
    return { items: out };
  }

  async pin(u: AuthUser, roomId: string, messageId: string | null) {
    const room = await this.access(u, roomId);
    if (!this.canPin(u, room, await this.me(u, roomId))) throw forbidden('You cannot pin messages in this chat');
    if (messageId && !(await this.prisma.chatMessage.findFirst({ where: { id: messageId, roomId, deletedAt: null } }))) throw notFound('Message');
    await this.prisma.chatRoom.update({ where: { id: roomId }, data: { pinnedMessageId: messageId } });
    await this.events.publish('chat.room', { roomId, userIds: await this.memberIds(room) });
    return this.room(u, roomId);
  }

  /** My own settings for a chat: keep it on top, no notifications. */
  async prefs(u: AuthUser, roomId: string, b: z.output<typeof chatMemberPrefsSchema>) {
    await this.access(u, roomId);
    await this.prisma.chatMember.update({
      where: { roomId_userId: { roomId, userId: u.id } },
      data: {
        ...(b.pinned === undefined ? {} : { pinnedAt: b.pinned ? new Date() : null }),
        ...(b.muted === undefined ? {} : { mutedUntil: b.muted ? FAR_FUTURE : null }),
      },
    });
    await this.events.publish('chat.room', { roomId, userIds: [u.id] });
    return { ok: true };
  }

  /** Chats by name, people I may write to, and messages in my chats. */
  async search(u: AuthUser, q: string) {
    const { items: rooms } = await this.rooms(u);
    const needle = q.toLowerCase();
    const matchedRooms = rooms.filter((r) => (r.kind === 'COMPANY' ? 'общий чат' : (r.title ?? '')).toLowerCase().includes(needle));
    const people = (await this.contacts(u, { q })).items.slice(0, 20);
    const titles = new Map(rooms.map((r) => [r.id, r.kind === 'COMPANY' ? null : r.title]));
    const kinds = new Map(rooms.map((r) => [r.id, r.kind]));
    const hits = await this.prisma.chatMessage.findMany({
      where: { roomId: { in: [...titles.keys()] }, deletedAt: null, text: { contains: q, mode: 'insensitive' } },
      orderBy: { id: 'desc' }, take: 40, include: MSG_INCLUDE,
    });
    return {
      rooms: matchedRooms,
      people,
      messages: hits.map((m) => ({ ...this.dto(m, u.id), room: { id: m.roomId, kind: kinds.get(m.roomId), title: titles.get(m.roomId) ?? null } })),
    };
  }

  /** «печатает…» / «записывает голосовое…»: relayed to the others, never stored. */
  async typing(u: AuthUser, roomId: string, kind: 'text' | 'voice') {
    let room: ChatRoom;
    try { room = await this.access(u, roomId); } catch { return; }
    const userIds = (await this.memberIds(room)).filter((id) => id !== u.id);
    if (userIds.length) await this.events.publish('chat.typing', { roomId, userId: u.id, name: u.fullName, kind, userIds });
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
    const own = m.senderId === u.id;
    if (!own && !isAdmin(u) && !(room.kind !== 'DIRECT' && room.kind !== 'COMPANY' && this.canManage(u, room, await this.me(u, room.id)))) {
      throw forbidden('You can delete only your own messages');
    }
    if (!m.deletedAt) {
      await this.prisma.$transaction(async (tx) => {
        await tx.chatMessage.update({ where: { id }, data: { deletedAt: new Date(), text: null } });
        // someone else's message removed by an admin: recorded (who, which chat, whose message) - never its content
        if (!own) await this.audit.record({ action: 'chat.message_deleted', entity: 'ChatMessage', entityId: id, after: { roomId: m.roomId, senderId: m.senderId } }, tx);
      });
    }
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

  @Authenticated() @Post('channels') @ApiZodBody(chatChannelSchema)
  createChannel(@CurrentUser() u: AuthUser, @ZodBody(chatChannelSchema) b: z.output<typeof chatChannelSchema>) { return this.chat.createChannel(u, b); }

  @Authenticated() @Get('rooms/:id/media')
  media(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodQuery(chatMediaQuerySchema) q: z.output<typeof chatMediaQuerySchema>) { return this.chat.media(u, id, q); }

  @Authenticated() @Post('rooms/:id/photo') @ApiConsumes('multipart/form-data')
  @ApiBody({ schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' } } } })
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 15 * 1024 * 1024 } }))
  photo(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @UploadedFile() file?: Express.Multer.File) {
    if (!file) throw fileRejected('Attach the photo as multipart field "file"');
    return this.chat.setPhoto(u, id, file.buffer);
  }

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

  @Authenticated() @Get('search')
  search(@CurrentUser() u: AuthUser, @ZodQuery(chatSearchSchema) q: z.output<typeof chatSearchSchema>) { return this.chat.search(u, q.q); }

  @Authenticated() @Post('rooms/:id/pin') @HttpCode(200) @ApiZodBody(chatPinSchema)
  pin(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(chatPinSchema) b: z.output<typeof chatPinSchema>) { return this.chat.pin(u, id, b.messageId); }

  @Authenticated() @Patch('rooms/:id/me') @ApiZodBody(chatMemberPrefsSchema)
  prefs(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(chatMemberPrefsSchema) b: z.output<typeof chatMemberPrefsSchema>) { return this.chat.prefs(u, id, b); }

  @Authenticated() @Patch('messages/:id') @ApiZodBody(chatEditSchema)
  edit(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(chatEditSchema) b: z.output<typeof chatEditSchema>) { return this.chat.edit(u, id, b); }

  @Authenticated() @Post('messages/:id/reactions') @HttpCode(200) @ApiZodBody(chatReactSchema)
  react(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(chatReactSchema) b: z.output<typeof chatReactSchema>) { return this.chat.react(u, id, b.emoji); }

  @Authenticated() @Throttle({ default: { limit: 20, ttl: 60_000 } }) @Post('messages/:id/forward') @HttpCode(200) @ApiZodBody(chatForwardSchema)
  forward(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(chatForwardSchema) b: z.output<typeof chatForwardSchema>) { return this.chat.forward(u, id, b.roomIds); }

  // sending is rate-limited per person (a stuck client or a flood cannot spam a chat)
  @Authenticated() @Throttle({ default: { limit: 60, ttl: 60_000 } }) @Post('rooms/:id/messages') @ApiZodBody(chatTextSchema)
  send(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(chatTextSchema) b: z.output<typeof chatTextSchema>) { return this.chat.sendText(u, id, b); }

  @Authenticated() @Throttle({ default: { limit: 30, ttl: 60_000 } }) @Post('rooms/:id/files') @ApiConsumes('multipart/form-data')
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

/** Socket side of the chat: «печатает…» from the app / browser (at most every 2 s per chat per connection). */
@WebSocketGateway({ cors: { origin: true } })
export class ChatGateway {
  private readonly last = new WeakMap<Socket, Map<string, number>>();
  constructor(private readonly chat: ChatService) {}

  @SubscribeMessage('chat:typing')
  async typing(@ConnectedSocket() socket: Socket, @MessageBody() body: { roomId?: unknown; kind?: unknown }) {
    const user = socket.data.principal as AuthUser | undefined;
    const roomId = typeof body?.roomId === 'string' && /^[0-9a-f-]{36}$/i.test(body.roomId) ? body.roomId : null;
    if (!user || !roomId) return;
    const seen = this.last.get(socket) ?? new Map<string, number>();
    this.last.set(socket, seen);
    if (Date.now() - (seen.get(roomId) ?? 0) < 2_000) return;
    seen.set(roomId, Date.now());
    await this.chat.typing(user, roomId, body.kind === 'voice' ? 'voice' : 'text');
  }
}

@Module({ imports: [PresenceModule], controllers: [ChatController], providers: [ChatService, ChatGateway] })
export class ChatModule {}

