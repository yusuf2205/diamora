import { Injectable } from '@nestjs/common';
import { Module } from '@nestjs/common';
import { Prisma, type WorkerProfile } from '@yusmus/database';
import { advance, initialRegState, parseUzs, type RegInput, type RegState } from '@yusmus/shared';
import { AuditService } from '../audit/audit.service';
import { EventBus } from '../events/events.module';
import { FilesService } from '../files/files.service';
import { PrismaService } from '../prisma/prisma.module';
import { nextCode, type Tx } from '../common/sequence';
import { money } from '../common/serialize';
import type { BotError, BotPrompt, BotReply, RegSummary } from './texts';

/** Channel-agnostic input: the bot process translates Telegram updates into this (D-005). */
export type BotInput =
  | { kind: 'command'; command: 'start' | 'cancel' }
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
    if (worker) return this.existingWorker(tx, worker, input, after);

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
      const created = await this.finalize(tx, ctx, r.state, photoIds, after);
      if (!created) {
        const back: RegState = { ...r.state, step: 'PHONE', returnToConfirm: true };
        await tx.registrationDraft.update({ where: { telegramUserId: ctx.telegramUserId }, data: { state: back as unknown as Prisma.InputJsonValue, photoFileIds: photoIds } });
        return { ...this.replyFor(back), error: 'PHONE_TAKEN' };
      }
      return { prompt: 'SUBMITTED' };
    }

    await tx.registrationDraft.update({ where: { telegramUserId: ctx.telegramUserId }, data: { state: r.state as unknown as Prisma.InputJsonValue, photoFileIds: photoIds } });
    return this.replyFor(r.state);
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

  private async existingWorker(tx: Tx, w: WorkerProfile, input: BotInput, after: Array<() => Promise<void>>): Promise<BotReply> {
    if (input.kind === 'location' && Math.abs(input.latitude) <= 90 && Math.abs(input.longitude) <= 180) {
      const now = new Date();
      await tx.workerProfile.update({ where: { id: w.id }, data: { latitude: input.latitude, longitude: input.longitude, locationReceivedAt: now } });
      await tx.workerLocation.create({ data: { workerId: w.id, latitude: input.latitude, longitude: input.longitude, receivedAt: now, source: 'TELEGRAM' } });
      await this.audit.record({ action: 'worker.location_update', entity: 'WorkerProfile', entityId: w.id, actorId: null, actorRole: 'WORKER', after: { latitude: input.latitude, longitude: input.longitude } }, tx);
      after.push(() => this.events.publish('worker.location.updated', { workerId: w.id, latitude: input.latitude, longitude: input.longitude, receivedAt: now.toISOString() }));
      return { prompt: 'LOCATION_UPDATED' };
    }
    switch (w.status) {
      case 'PENDING_APPROVAL': return { prompt: 'STATUS_PENDING' };
      case 'REJECTED': return { prompt: 'STATUS_REJECTED', rejectedReason: w.rejectedReason };
      case 'ACTIVE': return { prompt: 'STATUS_ACTIVE' };
      default: return { prompt: 'STATUS_PAUSED' };
    }
  }

  /**
   * Creates worker + declared collateral in the caller's transaction. Returns false when the phone is already taken
   * by an existing worker OR by a staff account — checked here, at submit time, not only later when the approving
   * admin hits the `User` collision (by then the registration looks "done" and the phone-owner would have to be
   * told to fix it after the fact). Same generic reply either way: never reveals who already holds the number.
   */
  private async finalize(tx: Tx, ctx: BotContext, state: RegState, photoIds: string[], after: Array<() => Promise<void>>): Promise<boolean> {
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
    return true;
  }
}

@Module({ providers: [RegistrationService], exports: [RegistrationService] })
export class RegistrationModule {}
