import { Controller, Delete, Get, HttpCode, Inject, Injectable, Logger, Module, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { createHash, randomBytes } from 'node:crypto';
import { statfs } from 'node:fs/promises';
import { dirname } from 'node:path';
import { AuditService } from '../audit/audit.service';
import { AdminBot } from './admin-bot';
import { CurrentUser, Roles } from '../common/decorators';
import type { AuthUser } from '../common/request-context';
import { ENV, Env } from '../config/env';
import { PrismaService } from '../prisma/prisma.module';
import { RedisService } from '../redis/redis.module';

const sha256 = (v: string) => createHash('sha256').update(v).digest('hex');
const LINK_TTL_S = 15 * 60;
const HEARTBEAT = 'alerts:heartbeat';
/** the NAS was silent longer than this -> «снова работает, был недоступен N мин» on the next start */
const DOWN_AFTER_MS = 3 * 60_000;
export const ALERT_PREFIX = 'alr_';

/** Something that can write to a Telegram chat (the bot in the worker process; a fake in tests). */
export interface AlertSender { send(chatId: bigint, text: string): Promise<void> }

const hhmm = (d: Date, tz: string) => d.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit', timeZone: tz });
const minutes = (ms: number) => {
  const m = Math.round(ms / 60_000);
  return m < 60 ? `${m} мин` : `${Math.floor(m / 60)} ч ${m % 60} мин`;
};

/**
 * Telegram alerts for the owner and admins. A staff member links the chat once (a `/start alr_<token>` deep link, like
 * the worker invites); the worker process then writes there when the NAS comes back after being down («был недоступен
 * 25 мин») and when the disk is running out. «Сайт не отвечает» itself is sent from OUTSIDE the NAS (infra/monitor,
 * a Cloudflare Worker) - a machine that is off cannot tell anyone.
 */
@Injectable()
export class AlertsService {
  private readonly log = new Logger('Alerts');
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly audit: AuditService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  // Redis in production; a process-local map without it (development, tests)
  private readonly mem = new Map<string, { v: string; until: number }>();
  private readonly kv = {
    get: async (k: string): Promise<string | null> => {
      if (this.redis.client) return this.redis.client.get(k);
      const e = this.mem.get(k);
      return e && e.until > Date.now() ? e.v : null;
    },
    set: async (k: string, v: string, ttlS?: number) => {
      if (this.redis.client) await (ttlS ? this.redis.client.set(k, v, 'EX', ttlS) : this.redis.client.set(k, v));
      else this.mem.set(k, { v, until: ttlS ? Date.now() + ttlS * 1000 : Infinity });
    },
    /** false when it already exists */
    setOnce: async (k: string, v: string, ttlS: number): Promise<boolean> => {
      if (this.redis.client) return (await this.redis.client.set(k, v, 'EX', ttlS, 'NX')) === 'OK';
      if ((await this.kv.get(k)) !== null) return false;
      this.mem.set(k, { v, until: Date.now() + ttlS * 1000 });
      return true;
    },
    del: async (k: string) => {
      if (this.redis.client) await this.redis.client.del(k);
      else this.mem.delete(k);
    },
  };

  async status(actor: AuthUser) {
    const u = await this.prisma.user.findUniqueOrThrow({ where: { id: actor.id }, select: { alertChatId: true } });
    return { linked: u.alertChatId !== null };
  }

  /** A one-time link (15 min) that opens the bot; pressing «Start» there links that chat. */
  async startLink(actor: AuthUser) {
    const token = randomBytes(18).toString('base64url');
    await this.kv.set(`alerts:link:${sha256(token)}`, actor.id, LINK_TTL_S);
    return { url: `https://t.me/${this.env.TELEGRAM_BOT_USERNAME}?start=${ALERT_PREFIX}${token}`, expiresInSeconds: LINK_TTL_S };
  }

  async unlink(actor: AuthUser) {
    await this.prisma.user.update({ where: { id: actor.id }, data: { alertChatId: null } });
    await this.audit.record({ action: 'alerts.unlinked', entity: 'User', entityId: actor.id });
    return { linked: false };
  }

  /** Bot side: `/start alr_<token>` in a private chat. Returns the reply text. */
  async completeLink(token: string, chatId: bigint): Promise<string> {
    const key = `alerts:link:${sha256(token)}`;
    const userId = await this.kv.get(key);
    if (!userId) return 'Ссылка устарела. Откройте «Оповещения в Telegram» в панели ещё раз.';
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { role: true, status: true, fullName: true } });
    if (!user || user.status !== 'ACTIVE' || (user.role !== 'SUPER_ADMIN' && user.role !== 'ADMIN')) return 'Оповещения доступны только администраторам.';
    await this.kv.del(key);
    await this.prisma.user.update({ where: { id: userId }, data: { alertChatId: chatId } });
    await this.audit.record({ action: 'alerts.linked', entity: 'User', entityId: userId, actorId: userId, actorRole: user.role });
    return `Готово, ${user.fullName}! Сюда будут приходить оповещения Diamoraa:\n• сайт или сервер не отвечает\n• сервер снова работает\n• на сервере заканчивается место

Номер этого чата: ${chatId} (нужен для внешнего сторожа, который пишет, даже когда сервер выключен).`;
  }

  /** Every linked, active admin. Failures to one chat never stop the others. */
  async notifyOwners(sender: AlertSender, text: string) {
    const rows = await this.prisma.user.findMany({
      where: { alertChatId: { not: null }, status: 'ACTIVE', role: { in: ['SUPER_ADMIN', 'ADMIN'] } },
      select: { alertChatId: true },
    });
    let sent = 0;
    for (const r of rows) {
      try {
        await sender.send(r.alertChatId!, text);
        sent++;
      } catch (e) {
        this.log.warn(`alert not delivered: ${(e as Error).message}`);
      }
    }
    this.log.log(`alert to ${sent} of ${rows.length} chats`);
    return sent;
  }

  /**
   * Worker start: if the last heartbeat is older than a few minutes the NAS (or the stack) was down - say so, with how
   * long. Then keep the heartbeat fresh (call `beat` every minute).
   */
  async onStart(sender: AlertSender, now = new Date()) {
    const last = Number(await this.kv.get(HEARTBEAT));
    await this.beat(now);
    if (!Number.isFinite(last) || last <= 0) return null; // first start ever
    const gap = now.getTime() - last;
    if (gap < DOWN_AFTER_MS) return null; // a normal restart (deploy)
    const tz = 'Asia/Tashkent'; // the owner's clock, whatever the server's TZ
    const text = `✅ Diamoraa снова работает.\nСервер был недоступен примерно ${minutes(gap)} (с ${hhmm(new Date(last), tz)} до ${hhmm(now, tz)}).`;
    await this.notifyOwners(sender, text);
    return text;
  }

  async beat(now = new Date()) {
    await this.kv.set(HEARTBEAT, String(now.getTime()));
  }

  /**
   * Backups: once a day, if a copy failed, is older than 36 h, or the external drive was not found - say which, in words.
   * `readStatus` is for tests; normally the backup job's status files (read-only mount).
   */
  async checkBackups(sender: AlertSender, now = new Date(), readStatus?: () => Promise<{ job: string; state: string; at: number }[]>) {
    const dir = this.env.BACKUP_STATUS_DIR;
    if (!dir && !readStatus) return null;
    let rows: { job: string; state: string; at: number }[];
    try {
      rows = readStatus ? await readStatus() : await (async () => {
        const { readdir, readFile } = await import('node:fs/promises');
        const out = [];
        for (const f of (await readdir(dir!)).filter((x) => x.endsWith('.status'))) {
          const [state, epoch] = (await readFile(`${dir}/${f}`, 'utf8')).trim().split(/\s+/);
          out.push({ job: f.replace(/\.status$/, ''), state, at: Number(epoch) * 1000 });
        }
        return out;
      })();
    } catch {
      return null;
    }
    const NAMES: Record<string, string> = { pg_dump: 'копия базы', minio_mirror: 'копия фото и файлов', config: 'копия настроек', verify: 'проверка восстановления', offsite: 'копия на внешнем диске', pg_basebackup: 'полная копия базы' };
    // the weekly full copy is fine for 8 days; everything else runs every night
    const maxAge = (job: string) => (job === 'pg_basebackup' ? 8 * 86_400_000 : 36 * 3600_000);
    const problems = rows.filter((r) => NAMES[r.job]).flatMap((r) => {
      if (r.state === 'nodrive') return [`• ${NAMES[r.job]}: внешний диск не найден — подключите его к NAS`];
      if (r.state !== 'ok') return [`• ${NAMES[r.job]}: не получилась`];
      if (!r.at || now.getTime() - r.at > maxAge(r.job)) return [`• ${NAMES[r.job]}: давно не обновлялась`];
      return [];
    });
    if (!problems.length) return null;
    const day = now.toISOString().slice(0, 10);
    if (!(await this.kv.setOnce(`alerts:backups:${day}`, '1', 36 * 3600))) return null;
    const text = [`⚠️ Резервные копии Diamoraa:`, ...problems, '', 'Данные в порядке, но копию нужно поправить — напишите разработчику.'].join('\n');
    await this.notifyOwners(sender, text);
    return text;
  }

  /** Disk of the NAS volume (seen through the mounted downloads folder): once a day while under 10 % free. */
  async checkDisk(sender: AlertSender, now = new Date(), measure?: () => Promise<{ free: number; total: number }>) {
    const file = this.env.RELEASE_MANIFEST;
    if (!file && !measure) return null;
    let free: number;
    let total: number;
    try {
      ({ free, total } = measure ? await measure() : await statfs(dirname(file!)).then((st) => ({ free: st.bavail * st.bsize, total: st.blocks * st.bsize })));
    } catch {
      return null;
    }
    if (!total || free / total >= 0.1) return null;
    const day = now.toISOString().slice(0, 10);
    if (!(await this.kv.setOnce(`alerts:disk:${day}`, '1', 36 * 3600))) return null; // already told today
    const gb = (b: number) => (b / 1024 ** 3).toFixed(1);
    const text = `⚠️ На сервере заканчивается место: свободно ${gb(free)} ГБ из ${gb(total)} ГБ (${Math.round((free / total) * 100)}%).\nУдалите лишние файлы на NAS, иначе фото, видео и резервные копии перестанут сохраняться.`;
    await this.notifyOwners(sender, text);
    return text;
  }
}

@ApiTags('alerts')
@ApiBearerAuth()
@Controller('me/telegram-alerts')
export class AlertsController {
  constructor(private readonly alerts: AlertsService) {}

  @Roles('SUPER_ADMIN', 'ADMIN') @Get()
  status(@CurrentUser() u: AuthUser) { return this.alerts.status(u); }

  @Roles('SUPER_ADMIN', 'ADMIN') @Post('link') @HttpCode(200)
  link(@CurrentUser() u: AuthUser) { return this.alerts.startLink(u); }

  @Roles('SUPER_ADMIN', 'ADMIN') @Delete()
  unlink(@CurrentUser() u: AuthUser) { return this.alerts.unlink(u); }
}

@Module({ controllers: [AlertsController], providers: [AlertsService], exports: [AlertsService] })
export class AlertsApiModule {}

/** Worker process: the service only (no HTTP). */
@Module({ providers: [AlertsService, AdminBot], exports: [AlertsService, AdminBot] })
export class AlertsModule {}
