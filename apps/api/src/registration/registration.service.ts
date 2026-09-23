import { Inject, Injectable } from '@nestjs/common';
import { Module } from '@nestjs/common';
import { Prisma, type WorkerProfile } from '@yusmus/database';
import { advance, initialRegState, parseUzs, type RegInput, type RegState } from '@yusmus/shared';
import { AuditService } from '../audit/audit.service';
import { ENV, Env } from '../config/env';
import { EventBus } from '../events/events.module';
import { FilesService } from '../files/files.service';
import { PrismaService } from '../prisma/prisma.module';
import { newOpaqueToken, nextCode, sha256, type Tx } from '../common/sequence';
import { money } from '../common/serialize';
import type { BotError, BotPrompt, BotReply, RegSummary } from './texts';

/** Channel-agnostic input: the bot process translates Telegram updates into this (D-005). `payload` is the
 * `/start <payload>` deep-link parameter (§ WORKER Telegram-only auth) — absent for an organic `/start`. */
export type BotInput =
  | { kind: 'command'; command: 'start' | 'cancel'; payload?: string }
  | { kind: 'text'; text: string }
  | { kind: 'contact'; phone: string; contactUserId: number | null }
  | { kind: 'location'; latitude: number; longitude: number }
  | { kind: 'photo'; download: () => Promise<{ buffer: Buffer; filename?: string }> }
  | { kind: 'action'; action: Extract<RegInput, { kind: 'action' }>['action'] };

export interface BotContext { telegramUserId: bigint; chatId: bigint }

const PROMPT_OF_STEP: Record<RegState['step'], BotPrompt> = {
  NAME: 'ASK_NAME', PHONE: 'ASK_PHONE', SECONDARY_PHONE: 'ASK_SECONDARY', LOCATION: 'ASK_LOCATION', COLLATERAL_TYPE: 'ASK_COLLATERAL_TYPE',
  COLLATERAL_AMOUNT: 'ASK_AMOUNT', COLLATERAL_DESCRIPTION: 'ASK_DESCRIPTION', COLLATERAL_PHOTOS: 'ASK_PHOTOS', NOTE: 'ASK_NOTE',
  CONFIRM: 'CONFIRM', EDIT_MENU: 'EDIT_MENU', SUBMITTED: 'SUBMITTED',
};

/**
 * ALL registration business logic. The Telegram bot is only an interface around `process`.
 * State lives in `registration_drafts` (PostgreSQL); updates of one Telegram user are serialised with an advisory lock.
 */
@Injectable()
export class RegistrationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly files: FilesService,
    private readonly audit: AuditService,
    private readonly events: EventBus,
    @Inject(ENV) private readonly env: Env,
  ) {}

  async process(ctx: BotContext, input: BotInput): Promise<BotReply> {
    const after: Array<() => Promise<void>> = [];
    const reply = await this.prisma.$transaction(
      async (tx) => {
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(${ctx.telegramUserId})`;
        return this.handle(tx, ctx, input, after);
      },
      { timeout: 60_000, maxWait: 10_000 },
    );
    for (const publish of after) await publish(); // realtime only AFTER COMMIT
    return reply;
  }

  private async handle(tx: Tx, ctx: BotContext, input: BotInput, after: Array<() => Promise<void>>): Promise<BotReply> {
    const worker = await tx.workerProfile.findUnique({ where: { telegramUserId: ctx.telegramUserId } });
    if (worker) return this.existingWorker(tx, ctx, worker, input, after);

    const startPayload = input.kind === 'command' && input.command === 'start' ? input.payload : undefined;
    if (startPayload) await this.linkTelegramSession(tx, ctx, startPayload); // side effect only: never changes the questionnaire itself

    let draft = await tx.registrationDraft.findUnique({ where: { telegramUserId: ctx.telegramUserId } });
    if (input.kind === 'command' && input.command === 'cancel') {
      if (draft) await tx.registrationDraft.delete({ where: { telegramUserId: ctx.telegramUserId } });
      return { prompt: 'CANCELLED' };
    }
    if (!draft || (input.kind === 'command' && input.command === 'start')) {
      draft = await tx.registrationDraft.upsert({
        where: { telegramUserId: ctx.telegramUserId },
        create: { telegramUserId: ctx.telegramUserId, chatId: ctx.chatId, state: initialRegState() as unknown as Prisma.InputJsonValue, photoFileIds: [] },
        update: { chatId: ctx.chatId, state: initialRegState() as unknown as Prisma.InputJsonValue, photoFileIds: [] },
      });
      return { prompt: 'WELCOME' };
    }
    if (input.kind === 'command') return this.replyFor(draft.state as unknown as RegState);

    const state = draft.state as unknown as RegState;
    const machineInput: RegInput =
      input.kind === 'contact' ? { kind: 'contact', phone: input.phone, contactUserId: input.contactUserId, senderUserId: Number(ctx.telegramUserId) }
      : input.kind === 'photo' ? { kind: 'photo' }
      : input;
    const r = advance(state, machineInput);
    if (r.error) return { ...this.replyFor(state), error: r.error };

    let photoIds = draft.photoFileIds;
    if (r.resetPhotos) photoIds = [];
    if (r.acceptPhoto && input.kind === 'photo') {
      try {
        const { buffer, filename } = await input.download();
        const asset = await this.files.uploadImage({ bucket: 'collateral', buffer, originalName: filename });
        photoIds = [...photoIds, asset.id];
      } catch {
        return { ...this.replyFor(state), error: 'PHOTO_FAILED' }; // state (and photo counter) stay as before
      }
    }

    if (r.submit) {
      const workerId = await this.finalize(tx, ctx, r.state, photoIds, after);
      if (!workerId) {
        const back: RegState = { ...r.state, step: 'PHONE', returnToConfirm: true };
        await tx.registrationDraft.update({ where: { telegramUserId: ctx.telegramUserId }, data: { state: back as unknown as Prisma.InputJsonValue, photoFileIds: photoIds } });
        return { ...this.replyFor(back), error: 'PHONE_TAKEN' };
      }
      // one tap already covered "confirm" (the questionnaire's own ✅ Подтвердить) — if it arrived via the app's
      // Telegram-login deep link, the SAME reply also carries the handoff button: no second, separate confirmation.
      const telegramHandoffUrl = await this.issueHandoffTicketIfLinked(tx, ctx, workerId);
      return telegramHandoffUrl ? { prompt: 'SUBMITTED', telegramHandoffUrl } : { prompt: 'SUBMITTED' };
    }

    await tx.registrationDraft.update({ where: { telegramUserId: ctx.telegramUserId }, data: { state: r.state as unknown as Prisma.InputJsonValue, photoFileIds: photoIds } });
    return this.replyFor(r.state);
  }

  // ---- WORKER Telegram-only login: app-initiated session <-> this Telegram identity, then a one-time handoff ticket ----
  /** Links a `/start <token>` deep-link token to this Telegram user. Fails closed (silently, as if absent) on any
   * expired/unknown/foreign token — an organic `/start` (no payload) never reaches here at all. */
  private async linkTelegramSession(tx: Tx, ctx: BotContext, payload: string): Promise<string | null> {
    const row = await tx.telegramLoginSession.findUnique({ where: { tokenHash: sha256(payload) } });
    if (!row || row.expiresAt <= new Date()) return null;
    if (row.telegramUserId !== null) return row.telegramUserId === ctx.telegramUserId ? row.id : null; // §18: a foreign token never links
    await tx.telegramLoginSession.update({ where: { id: row.id }, data: { telegramUserId: ctx.telegramUserId, chatId: ctx.chatId, linkedAt: new Date() } });
    await this.audit.record({ action: 'worker.telegram_linked', entity: 'TelegramLoginSession', entityId: row.id, actorId: null, actorRole: 'WORKER' }, tx);
    return row.id;
  }

  /** Only if THIS telegramUserId has a session linked (and not yet turned into an unconsumed ticket for this same
   * worker) — a bot conversation that never went through the app's "Войти через Telegram" gets no button, ever. */
  private async issueHandoffTicketIfLinked(tx: Tx, ctx: BotContext, workerId: string): Promise<string | null> {
    const session = await tx.telegramLoginSession.findFirst({
      where: { telegramUserId: ctx.telegramUserId, linkedAt: { not: null }, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
    return session ? this.issueHandoffTicket(tx, session.id, ctx, workerId) : null;
  }

  private async issueHandoffTicket(tx: Tx, sessionId: string, ctx: BotContext, workerId: string): Promise<string> {
    const token = newOpaqueToken();
    const expiresAt = new Date(Date.now() + this.env.TELEGRAM_HANDOFF_TICKET_TTL_MINUTES * 60_000);
    await tx.telegramHandoffTicket.create({ data: { tokenHash: sha256(token), sessionId, telegramUserId: ctx.telegramUserId, workerId, expiresAt } });
    return `${this.env.PUBLIC_API_URL}/app/auth/telegram?t=${token}`;
  }

  private statusReply(w: WorkerProfile): BotReply {
    switch (w.status) {
      case 'PENDING_APPROVAL': return { prompt: 'STATUS_PENDING' };
      case 'REJECTED': return { prompt: 'STATUS_REJECTED', rejectedReason: w.rejectedReason };
      case 'ACTIVE': return { prompt: 'STATUS_ACTIVE' };
      default: return { prompt: 'STATUS_PAUSED' };
    }
  }

  private replyFor(state: RegState): BotReply {
    const d = state.data;
    const reply: BotReply = { prompt: PROMPT_OF_STEP[state.step] };
    if (state.step === 'COLLATERAL_PHOTOS') reply.photoCount = d.photoCount;
    if (state.step === 'CONFIRM') {
      const summary: RegSummary = {
        fullName: d.fullName, phone: d.phone, secondaryPhone: d.secondaryPhone, hasLocation: d.latitude !== undefined,
        collateralType: d.collateralType, collateralAmount: d.collateralAmount, collateralDescription: d.collateralDescription, photoCount: d.photoCount, note: d.note,
      };
      reply.summary = summary;
    }
    return reply;
  }

  private async existingWorker(tx: Tx, ctx: BotContext, w: WorkerProfile, input: BotInput, after: Array<() => Promise<void>>): Promise<BotReply> {
    if (input.kind === 'location' && Math.abs(input.latitude) <= 90 && Math.abs(input.longitude) <= 180) {
      const now = new Date();
      await tx.workerProfile.update({ where: { id: w.id }, data: { latitude: input.latitude, longitude: input.longitude, locationReceivedAt: now } });
      await tx.workerLocation.create({ data: { workerId: w.id, latitude: input.latitude, longitude: input.longitude, receivedAt: now, source: 'TELEGRAM' } });
      await this.audit.record({ action: 'worker.location_update', entity: 'WorkerProfile', entityId: w.id, actorId: null, actorRole: 'WORKER', after: { latitude: input.latitude, longitude: input.longitude } }, tx);
      after.push(() => this.events.publish('worker.location.updated', { workerId: w.id, latitude: input.latitude, longitude: input.longitude, receivedAt: now.toISOString() }));
      return { prompt: 'LOCATION_UPDATED' };
    }
    // WORKER Telegram-only login (§): this bot conversation IS the login for a returning worker. One tap on the
    // handoff button that follows — whatever the status text says — opens Diamoraa straight to the right screen.
    if (input.kind === 'command' && input.command === 'start' && input.payload) {
      const sessionId = await this.linkTelegramSession(tx, ctx, input.payload);
      if (sessionId) {
        const telegramHandoffUrl = await this.issueHandoffTicket(tx, sessionId, ctx, w.id);
        return { ...this.statusReply(w), telegramHandoffUrl };
      }
    }
    return this.statusReply(w);
  }

  /**
   * Creates worker + declared collateral in the caller's transaction. Returns false when the phone is already taken
   * by an existing worker OR by a staff account — checked here, at submit time, not only later when the approving
   * admin hits the `User` collision (by then the registration looks "done" and the phone-owner would have to be
   * told to fix it after the fact). Same generic reply either way: never reveals who already holds the number.
   * Returns the new worker's id on success (so a linked Telegram login session can be handed a ticket for it).
   */
  private async finalize(tx: Tx, ctx: BotContext, state: RegState, photoIds: string[], after: Array<() => Promise<void>>): Promise<string | false> {
    const d = state.data;
    const phoneTaken = await tx.workerProfile.findUnique({ where: { phone: d.phone as string }, select: { id: true } });
    const staffPhoneTaken = phoneTaken ? null : await tx.user.findUnique({ where: { phone: d.phone as string }, select: { id: true } });
    if (phoneTaken || staffPhoneTaken) return false;
    const now = new Date();
    const worker = await tx.workerProfile.create({
      data: {
        telegramUserId: ctx.telegramUserId, telegramChatId: ctx.chatId, code: await nextCode(tx, 'worker', 'W-', 4),
        fullName: d.fullName as string, phone: d.phone as string, secondaryPhone: d.secondaryPhone ?? null,
        latitude: d.latitude, longitude: d.longitude, locationReceivedAt: now, status: 'PENDING_APPROVAL', notes: d.note ?? null,
      },
    });
    await tx.workerLocation.create({ data: { workerId: worker.id, latitude: d.latitude as number, longitude: d.longitude as number, receivedAt: now, source: 'TELEGRAM' } });

    const isMoney = d.collateralType === 'MONEY';
    const collateral = await tx.workerCollateral.create({
      data: {
        code: await nextCode(tx, 'collateral', 'COL-', 6), workerId: worker.id, type: d.collateralType as 'MONEY' | 'ITEM', status: 'PENDING',
        amount: isMoney ? parseUzs(d.collateralAmount as string) : null, description: isMoney ? null : (d.collateralDescription as string),
      },
    });
    for (const fileId of photoIds) await tx.collateralPhoto.create({ data: { collateralId: collateral.id, fileId } });
    await tx.collateralHistory.create({
      data: {
        collateralId: collateral.id, type: 'DECLARED', actorId: null, actorLabel: `${worker.fullName} (Telegram)`,
        note: isMoney ? 'Залог деньгами заявлен при регистрации' : 'Залог вещью заявлен при регистрации',
        snapshot: { status: 'PENDING', type: collateral.type, amount: money(collateral.amount), description: collateral.description, photos: photoIds.length },
      },
    });
    await this.audit.record({ action: 'worker.register', entity: 'WorkerProfile', entityId: worker.id, actorId: null, actorRole: 'WORKER', after: { code: worker.code, fullName: worker.fullName, phone: worker.phone } }, tx);
    await tx.registrationDraft.delete({ where: { telegramUserId: ctx.telegramUserId } });

    after.push(() => this.events.publish('worker.created', { workerId: worker.id, code: worker.code, fullName: worker.fullName, status: worker.status }));
    after.push(() => this.events.publish('collateral.created', { collateralId: collateral.id, workerId: worker.id, type: collateral.type, status: collateral.status }));
    return worker.id;
  }
}

@Module({ providers: [RegistrationService], exports: [RegistrationService] })
export class RegistrationModule {}
