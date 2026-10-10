import { Controller, Delete, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Post, Put, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { KIT_METERS } from '@diamoraa/shared';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { CurrentUser, Perm, Roles } from '../common/decorators';
import { fileRejected, forbidden, notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { money } from '../common/serialize';
import { ZodBody } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { FilesModule, FilesService } from '../files/files.service';
import { LedgerModule, LedgerService } from '../ledger/ledger.service';
import { AppNotifier } from '../notifications/app-notifier';
import { PrismaService } from '../prisma/prisma.module';
import { periodRange } from '../reports/reports.service';
import { PayRateModule, PayRateService } from '../settings/pay-rate.service';

const TASHKENT_MS = 5 * 3_600_000;
const monthKey = (from: Date) => {
  const local = new Date(from.getTime() + TASHKENT_MS);
  return `${local.getUTCFullYear()}-${String(local.getUTCMonth() + 1).padStart(2, '0')}`;
};
const MONTHS_RU = ['январь', 'февраль', 'март', 'апрель', 'май', 'июнь', 'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'];
/** share of the checked metres that was accepted (defects only; «на доработку» is not a defect), 1 decimal */
const quality = (accepted: number, defective: number) => (accepted + defective > 0 ? Math.round((accepted / (accepted + defective)) * 1000) / 10 : null);
const defectPercent = (accepted: number, defective: number) => (accepted + defective > 0 ? (defective / (accepted + defective)) * 100 : 0);

export const qualityBonusSchema = z.object({
  enabled: z.boolean(),
  /** + this % of the month's earnings */
  percent: z.coerce.number().int().min(1).max(100),
  /** at most this % of defects in the month */
  maxDefectPercent: z.coerce.number().int().min(0).max(50),
  /** at least this many metres accepted in the month */
  minMeters: z.coerce.number().int().min(0).max(100_000),
});

/**
 * «Мой прогресс» for a worker: her month and all time, quality, records, every check of her work with the defect photos
 * and the comment, and the quality bonus (owner, 2026-10-11): + N % of the month's earnings when the month had few
 * defects. The bonus is paid by the worker process on the 1st for the month before, once (ledger idempotency key).
 */
@Injectable()
export class ProgressService {
  constructor(
    private readonly prisma: PrismaService, private readonly files: FilesService, private readonly ledger: LedgerService,
    private readonly payRate: PayRateService, private readonly audit: AuditService, private readonly events: EventBus,
  ) {}

  async bonusSettings() {
    const s = await this.prisma.qualityBonusSettings.findUnique({ where: { id: 1 } });
    return { enabled: s?.enabled ?? false, percent: s?.percent ?? 5, maxDefectPercent: s?.maxDefectPercent ?? 0, minMeters: s?.minMeters ?? KIT_METERS };
  }

  async setBonus(actor: AuthUser, b: z.output<typeof qualityBonusSchema>) {
    const before = await this.prisma.qualityBonusSettings.findUnique({ where: { id: 1 } });
    // a month counts from the moment the bonus was switched on (never paid for the months before it)
    const enabledAt = b.enabled ? (before?.enabled && before.enabledAt ? before.enabledAt : new Date()) : null;
    const data = { ...b, enabledAt, updatedById: actor.id };
    await this.prisma.qualityBonusSettings.upsert({ where: { id: 1 }, create: { id: 1, ...data }, update: data });
    await this.audit.record({ action: 'settings.quality_bonus', entity: 'QualityBonusSettings', entityId: null, before: before ? await this.bonusSettings() : null, after: b });
    return this.bonusSettings();
  }

  /** accepted / defective metres of one worker (or everyone) between two moments */
  private async checked(from: Date, to: Date, workerId?: string) {
    const rows = await this.prisma.qualityInspection.groupBy({
      by: ['assignmentId'], where: { inspectedAt: { gte: from, lt: to }, ...(workerId ? { assignment: { workerId } } : {}) },
      _sum: { acceptedMeters: true, defectiveMeters: true },
    });
    if (!rows.length) return new Map<string, { accepted: number; defective: number }>();
    const owners = new Map((await this.prisma.workAssignment.findMany({ where: { id: { in: rows.map((r) => r.assignmentId) } }, select: { id: true, workerId: true } })).map((a) => [a.id, a.workerId]));
    const out = new Map<string, { accepted: number; defective: number }>();
    for (const r of rows) {
      const w = owners.get(r.assignmentId)!;
      const cur = out.get(w) ?? { accepted: 0, defective: 0 };
      cur.accepted += Number(r._sum.acceptedMeters ?? 0);
      cur.defective += Number(r._sum.defectiveMeters ?? 0);
      out.set(w, cur);
    }
    return out;
  }

  private async earned(workerId: string, from: Date, to: Date, types: ('EARNING' | 'BONUS')[]) {
    const s = await this.prisma.workerLedgerTransaction.aggregate({ _sum: { amount: true }, where: { workerId, type: { in: types }, createdAt: { gte: from, lt: to } } });
    return s._sum.amount ?? 0n;
  }

  async forWorker(workerId: string, now = new Date()) {
    const { from, to } = periodRange('month', 0, now);
    const [inspections, rate, bonus, monthEarning, monthBonus] = await Promise.all([
      this.prisma.qualityInspection.findMany({
        where: { assignment: { workerId } }, orderBy: { inspectedAt: 'desc' },
        include: { assignment: { select: { code: true, productModel: { select: { name: true } }, color: { select: { name: true } } } } },
      }),
      this.payRate.current(),
      this.bonusSettings(),
      this.earned(workerId, from, to, ['EARNING']),
      this.earned(workerId, from, to, ['BONUS']),
    ]);
    // per month (Tashkent time), all time
    const byMonth = new Map<string, { accepted: number; defective: number }>();
    let allAccepted = 0, allDefective = 0;
    for (const q of inspections) {
      const k = monthKey(q.inspectedAt);
      const m = byMonth.get(k) ?? { accepted: 0, defective: 0 };
      m.accepted += Number(q.acceptedMeters); m.defective += Number(q.defectiveMeters);
      byMonth.set(k, m);
      allAccepted += Number(q.acceptedMeters); allDefective += Number(q.defectiveMeters);
    }
    const thisKey = monthKey(from);
    const month = byMonth.get(thisKey) ?? { accepted: 0, defective: 0 };
    const earlier = [...byMonth.entries()].filter(([k]) => k !== thisKey);
    const best = earlier.reduce<{ month: string; meters: number } | null>((b, [k, v]) => (v.accepted > (b?.meters ?? 0) ? { month: k, meters: v.accepted } : b), null);
    const defects = defectPercent(month.accepted, month.defective);
    const qualifies = month.accepted >= bonus.minMeters && defects <= bonus.maxDefectPercent;
    return {
      month: thisKey,
      thisMonth: { acceptedMeters: month.accepted, defectiveMeters: month.defective, qualityPercent: quality(month.accepted, month.defective), earned: money(monthEarning + monthBonus)! },
      allTime: { acceptedMeters: allAccepted, defectiveMeters: allDefective, qualityPercent: quality(allAccepted, allDefective), checks: inspections.length },
      /** her best month before this one; `record`: this month already beat it */
      best, record: !!best && month.accepted > best.meters,
      bonus: {
        ...bonus, qualifies: bonus.enabled ? qualifies : false, defectPercent: Math.round(defects * 10) / 10,
        /** what this month would bring if it ended now */
        expected: money(bonus.enabled && qualifies ? (monthEarning * BigInt(bonus.percent)) / 100n : 0n)!,
        paidThisMonth: money(monthBonus)!,
      },
      ratePerKit: money(rate.ratePerKit)!, kitMeters: KIT_METERS,
      /** every check of her work, newest first: what was accepted, the defects with the photos and the comment */
      checks: inspections.slice(0, 30).map((q) => ({
        id: q.id, at: q.inspectedAt.toISOString(), code: q.assignment.code, product: q.assignment.productModel.name, color: q.assignment.color.name,
        result: q.result, broughtMeters: Number(q.broughtMeters), acceptedMeters: Number(q.acceptedMeters),
        defectiveMeters: Number(q.defectiveMeters), reworkMeters: Number(q.reworkMeters), comment: q.comment,
        photos: q.photoFileIds.map((id) => this.files.ref(id)).filter((x) => x !== null),
      })),
    };
  }

  /** On the 1st (any time that day or later, once): the quality bonus for the month before. */
  async payMonthlyBonuses(notifier: AppNotifier, now = new Date()) {
    const s = await this.prisma.qualityBonusSettings.findUnique({ where: { id: 1 } });
    if (!s?.enabled || !s.enabledAt) return;
    const prev = periodRange('month', -1, now);
    const key = monthKey(prev.from);
    if (s.lastPaidMonth === key || s.enabledAt >= prev.to) return; // done, or switched on only after that month
    const checked = await this.checked(prev.from, prev.to);
    const month = MONTHS_RU[Number(key.slice(5)) - 1];
    for (const [workerId, m] of checked) {
      if (m.accepted < s.minMeters || defectPercent(m.accepted, m.defective) > s.maxDefectPercent) continue;
      const earning = await this.earned(workerId, prev.from, prev.to, ['EARNING']);
      const amount = (earning * BigInt(s.percent)) / 100n;
      if (amount <= 0n) continue;
      const paid = await this.ledger.bonus(workerId, amount, `qbonus:${workerId}:${key}`, `Бонус за качество: ${month}, +${s.percent}%`);
      if (!paid) continue; // already paid (a second worker process, or a restart in between)
      const w = await this.prisma.workerProfile.findUnique({ where: { id: workerId }, select: { userId: true, assignedManagerId: true } });
      await notifier.notify([w?.userId ?? null], {
        type: 'bonus.quality', title: `Бонус за качество! +${money(amount)} сум`, link: '/worker/progress',
        body: `За ${month}: брака ${Math.round(defectPercent(m.accepted, m.defective) * 10) / 10}% — спасибо за аккуратную работу!`, dedupe: `qbonus:${workerId}:${key}`,
      });
      const after = await this.ledger.summaryForWorker(workerId);
      await this.events.publish('worker.balance_updated', { workerId, balance: after.balance, earned: after.earned, paid: after.paid, managerId: w?.assignedManagerId ?? null });
    }
    await this.prisma.qualityBonusSettings.update({ where: { id: 1 }, data: { lastPaidMonth: key } });
  }

  /** «Как шить»: the model's instruction video, for any worker (also when the model is not in the public catalog). */
  async instruction(modelId: string) {
    const m = await this.prisma.productModel.findUnique({ where: { id: modelId }, select: { id: true, name: true, videoFileId: true } });
    if (!m) throw notFound('Model');
    return { id: m.id, name: m.name, video: this.files.ref(m.videoFileId, 6 * 3600) };
  }

  async setInstruction(actor: AuthUser, modelId: string, file: { buffer: Buffer; originalName?: string } | null) {
    const m = await this.prisma.productModel.findUnique({ where: { id: modelId }, select: { id: true, videoFileId: true } });
    if (!m) throw notFound('Model');
    const asset = file ? await this.files.uploadVideo({ bucket: 'products', buffer: file.buffer, uploadedById: actor.id, originalName: file.originalName }) : null;
    await this.prisma.productModel.update({ where: { id: modelId }, data: { videoFileId: asset?.id ?? null } });
    await this.audit.record({ action: asset ? 'catalog.instruction_set' : 'catalog.instruction_removed', entity: 'ProductModel', entityId: modelId, before: { videoFileId: m.videoFileId }, after: { videoFileId: asset?.id ?? null } });
    await this.events.publish('catalog.item.updated', { itemId: modelId });
    return this.instruction(modelId);
  }

  /** a defect photo taken at acceptance (staff), before the acceptance itself is sent */
  async qualityPhoto(actor: AuthUser, file: { buffer: Buffer; originalName?: string }) {
    const asset = await this.files.uploadImage({ bucket: 'quality', buffer: file.buffer, uploadedById: actor.id, originalName: file.originalName });
    return this.files.ref(asset.id)!;
  }
}

@ApiTags('progress')
@ApiBearerAuth()
@Controller()
export class ProgressController {
  constructor(private readonly progress: ProgressService) {}

  @Roles('WORKER') @Get('work/progress')
  mine(@CurrentUser() u: AuthUser) {
    if (!u.workerId) throw forbidden();
    return this.progress.forWorker(u.workerId);
  }

  @Roles('WORKER') @Get('work/models/:id/instruction')
  instruction(@Param('id', new ParseUUIDPipe()) id: string) { return this.progress.instruction(id); }

  @Perm('CATALOG_VIEW', 'CATALOG_MANAGE') @Get('admin/catalog/:id/instruction')
  adminInstruction(@Param('id', new ParseUUIDPipe()) id: string) { return this.progress.instruction(id); }

  @Perm('CATALOG_MANAGE') @Post('admin/catalog/:id/instruction') @HttpCode(200) @ApiConsumes('multipart/form-data')
  @ApiBody({ schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' } } } })
  @UseInterceptors(FileInterceptor('file'))
  setInstruction(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @UploadedFile() file?: Express.Multer.File) {
    if (!file) throw fileRejected('Attach the video as multipart field "file"');
    return this.progress.setInstruction(u, id, { buffer: file.buffer, originalName: file.originalname });
  }

  @Perm('CATALOG_MANAGE') @Delete('admin/catalog/:id/instruction') @HttpCode(200)
  removeInstruction(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.progress.setInstruction(u, id, null); }

  @Perm('ASSIGNMENT_ACCEPT') @Post('admin/quality-photos') @HttpCode(201) @ApiConsumes('multipart/form-data')
  @ApiBody({ schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' } } } })
  @UseInterceptors(FileInterceptor('file'))
  qualityPhoto(@CurrentUser() u: AuthUser, @UploadedFile() file?: Express.Multer.File) {
    if (!file) throw fileRejected('Attach the photo as multipart field "file"');
    return this.progress.qualityPhoto(u, { buffer: file.buffer, originalName: file.originalname });
  }

  @Perm('PAY_RATE_MANAGE', 'SETTINGS_MANAGE') @Get('admin/quality-bonus')
  bonus() { return this.progress.bonusSettings(); }

  @Perm('PAY_RATE_MANAGE') @Put('admin/quality-bonus')
  setBonus(@CurrentUser() u: AuthUser, @ZodBody(qualityBonusSchema) b: z.output<typeof qualityBonusSchema>) { return this.progress.setBonus(u, b); }
}

@Module({ imports: [FilesModule, LedgerModule, PayRateModule], controllers: [ProgressController], providers: [ProgressService], exports: [ProgressService] })
export class ProgressModule {}

/** Worker process: the monthly quality bonus only. */
@Module({ imports: [FilesModule, LedgerModule, PayRateModule], providers: [ProgressService], exports: [ProgressService] })
export class ProgressWorkerModule {}
