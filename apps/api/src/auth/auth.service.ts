import { Inject, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { User, UserSession } from '@yusmus/database';
import { isStaffRole, type Permission, type Role } from '@yusmus/shared';
import { createHash, randomBytes } from 'node:crypto';
import { AuditService } from '../audit/audit.service';
import { accountDisabled, AppError, invalidCredentials, notFound, rateLimited, sessionRevoked, ticketInvalid, unauthenticated, userNotFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { ENV, Env } from '../config/env';
import { PrismaService } from '../prisma/prisma.module';
import { PasswordService, SessionAuthService } from './auth-core';

export interface ClientMeta { ip?: string; userAgent?: string }
export interface DeviceInput { installId: string; platform: string; name?: string; appVersion?: string }
export interface MeDto { id: string; fullName: string; phone: string; role: Role; workerId: string | null; permissions: Permission[] }
export interface AuthResult { accessToken: string; accessTokenExpiresAt: string; refreshToken: string; refreshTokenExpiresAt: string; user: MeDto }
export type TelegramExchangeResult = AuthResult | { status: 'PENDING_APPROVAL' | 'REJECTED' | 'PAUSED'; rejectedReason?: string | null };

const sha256 = (v: string) => createHash('sha256').update(v).digest('hex');
const newRefresh = () => randomBytes(32).toString('base64url');
const MIN = 60_000;

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly passwords: PasswordService,
    private readonly sessionAuth: SessionAuthService,
    private readonly audit: AuditService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  // ---- ADMIN: phone + password ---------------------------------------------------------------------------------
  async adminLogin(input: { phone: string; password: string; device: DeviceInput }, meta: ClientMeta): Promise<AuthResult> {
    await this.assertNotThrottled(input.phone, meta.ip);
    const user = await this.prisma.user.findUnique({ where: { phone: input.phone } });
    const ok = user && isStaffRole(user.role) && user.passwordHash ? await this.passwords.verify(user.passwordHash, input.password) : (await this.passwords.verifyDummy(input.password), false);
    if (!user || !ok) {
      await this.attempt(input.phone, meta.ip, false, user ? 'bad_password' : 'unknown_phone');
      throw invalidCredentials();
    }
    if (user.status !== 'ACTIVE') {
      await this.attempt(input.phone, meta.ip, false, 'account_disabled');
      throw accountDisabled();
    }
    await this.attempt(input.phone, meta.ip, true, 'login');
    return this.createSession(user, input.device, meta);
  }

  // ---- unified login: the human only gives a phone, the server decides everything else ---------------------------------
  /**
   * Step 1 of the single Login Screen (no role selector, ever — the client never asks "who are you"). Looks up the
   * phone, tells the client which second field to show next. STAFF: password, as always. WORKER: no phone/password/OTP
   * flow exists any more (Telegram-only login, §telegramSession/telegramExchange below) — the client shows the
   * "Войти через Telegram" affordance and never asks for anything else. Never reveals staff vs worker beyond the
   * method needed.
   */
  async identify(phone: string, meta: ClientMeta): Promise<{ method: 'PASSWORD' | 'TELEGRAM_ONLY' }> {
    await this.assertNotThrottled(phone, meta.ip);
    const user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user) throw userNotFound();
    if (user.status !== 'ACTIVE') throw accountDisabled();
    return { method: isStaffRole(user.role) ? 'PASSWORD' : 'TELEGRAM_ONLY' };
  }

  // ---- WORKER: Telegram-only login (no phone/password/OTP in the app) -------------------------------------------------
  /**
   * The app taps this to start a login: a `/start <token>` deep link the bot will link to whichever Telegram account
   * opens it. `tokenHash` only is stored (never the raw token) — same pattern as a refresh token.
   */
  async telegramSession(device: DeviceInput): Promise<{ deepLink: string; expiresAt: string }> {
    const token = newRefresh();
    const expiresAt = new Date(Date.now() + this.env.TELEGRAM_LOGIN_SESSION_TTL_MINUTES * MIN);
    await this.prisma.telegramLoginSession.create({ data: { tokenHash: sha256(token), installId: device.installId, expiresAt } });
    return { deepLink: `https://t.me/${this.env.TELEGRAM_BOT_USERNAME}?start=${token}`, expiresAt: expiresAt.toISOString() };
  }

  /**
   * The app POSTs the one-time ticket from the bot's handoff URL. Never a password, never a JWT in the URL, never a
   * client-trusted role (§8) — the backend alone decides, from `ticket.workerId` and that worker's CURRENT status
   * (never whatever it was when the ticket was issued), whether to issue a real session or a "not ready yet" outcome.
   */
  async telegramExchange(input: { ticket: string; device: DeviceInput }, meta: ClientMeta): Promise<TelegramExchangeResult> {
    const hash = sha256(input.ticket);
    const now = new Date();
    const ticket = await this.prisma.$transaction(async (tx) => {
      const row = await tx.telegramHandoffTicket.findUnique({ where: { tokenHash: hash } });
      if (!row || row.consumedAt || row.expiresAt <= now) return null;
      const consumed = await tx.telegramHandoffTicket.updateMany({ where: { id: row.id, consumedAt: null }, data: { consumedAt: now } });
      return consumed.count === 1 ? row : null; // lost a race with a concurrent exchange of the same ticket
    });
    if (!ticket) {
      await this.audit.record({ action: 'worker.telegram_login_failed', entity: 'TelegramHandoffTicket', actorId: null, actorRole: 'WORKER', after: { reason: 'invalid_or_consumed_ticket' } });
      throw ticketInvalid();
    }
    await this.audit.record({ action: 'worker.telegram_handoff_consumed', entity: 'TelegramHandoffTicket', entityId: ticket.id, actorId: null, actorRole: 'WORKER' });
    const worker = ticket.workerId ? await this.prisma.workerProfile.findUnique({ where: { id: ticket.workerId }, include: { user: true } }) : null;
    if (!worker) {
      await this.audit.record({ action: 'worker.telegram_login_failed', entity: 'TelegramHandoffTicket', entityId: ticket.id, actorId: null, actorRole: 'WORKER', after: { reason: 'no_worker' } });
      throw ticketInvalid();
    }
    if (worker.status === 'PENDING_APPROVAL') return { status: 'PENDING_APPROVAL' };
    if (worker.status === 'REJECTED') return { status: 'REJECTED', rejectedReason: worker.rejectedReason };
    if (worker.status !== 'ACTIVE' || !worker.user || worker.user.status !== 'ACTIVE') {
      await this.audit.record({ action: 'worker.telegram_login_failed', entity: 'WorkerProfile', entityId: worker.id, actorId: worker.user?.id ?? null, actorRole: 'WORKER', after: { reason: 'not_active' } });
      return { status: 'PAUSED' };
    }
    await this.audit.record({ action: 'worker.telegram_login_success', entity: 'User', entityId: worker.user.id, actorId: worker.user.id, actorRole: 'WORKER' });
    return this.createSession(worker.user, input.device, meta);
  }

  // ---- sessions ------------------------------------------------------------------------------------------------------
  private async createSession(user: User, d: DeviceInput, meta: ClientMeta): Promise<AuthResult> {
    const now = new Date();
    const refresh = newRefresh();
    const session = await this.prisma.$transaction(async (tx) => {
      // one live session per app install: a new login replaces the previous one there
      const stale = await tx.userSession.findMany({ where: { userId: user.id, installId: d.installId, revokedAt: null }, select: { id: true } });
      if (stale.length) {
        await tx.userSession.updateMany({ where: { id: { in: stale.map((s) => s.id) } }, data: { revokedAt: now, revokedReason: 'new_login_on_device' } });
        this.sessionAuth.invalidateSessions(stale.map((s) => s.id));
      }
      const s = await tx.userSession.create({
        data: {
          userId: user.id, installId: d.installId, deviceName: d.name, platform: d.platform, appVersion: d.appVersion,
          refreshTokenHash: sha256(refresh), expiresAt: this.refreshExpiry(now), ip: meta.ip, userAgent: meta.userAgent?.slice(0, 300),
        },
      });
      await tx.user.update({ where: { id: user.id }, data: { lastLoginAt: now } });
      await this.audit.record({ action: 'auth.login', entity: 'UserSession', entityId: s.id, actorId: user.id, actorRole: user.role, after: { platform: d.platform } }, tx);
      return s;
    });
    return this.result(user, session, refresh);
  }

  async refresh(refreshToken: string, meta: ClientMeta): Promise<AuthResult> {
    const hash = sha256(refreshToken);
    for (let attempt = 0; attempt < 2; attempt++) {
      const now = new Date();
      const s = await this.prisma.userSession.findFirst({ where: { OR: [{ refreshTokenHash: hash }, { previousRefreshTokenHash: hash }] }, include: { user: true } });
      if (!s) throw unauthenticated('Invalid refresh token');
      if (s.revokedAt || s.expiresAt <= now || s.user.status !== 'ACTIVE') throw sessionRevoked();
      const isCurrent = s.refreshTokenHash === hash;
      if (!isCurrent) {
        // rotated token came back: within the grace window = a lost response on a flaky network; later = theft -> kill the session
        const inGrace = s.rotatedAt !== null && now.getTime() - s.rotatedAt.getTime() <= this.env.REFRESH_REUSE_GRACE_SECONDS * 1000;
        if (!inGrace) {
          await this.revokeById(s.id, 'refresh_token_reuse');
          await this.audit.record({ action: 'auth.refresh_reuse_detected', entity: 'UserSession', entityId: s.id, actorId: s.userId, actorRole: s.user.role });
          throw sessionRevoked();
        }
      }
      const next = newRefresh();
      const swapped = await this.prisma.userSession.updateMany({
        where: { id: s.id, refreshTokenHash: s.refreshTokenHash, revokedAt: null },
        data: { previousRefreshTokenHash: isCurrent ? s.refreshTokenHash : s.previousRefreshTokenHash, refreshTokenHash: sha256(next), rotatedAt: now, lastUsedAt: now, expiresAt: this.refreshExpiry(now), ip: meta.ip ?? s.ip },
      });
      if (swapped.count !== 1) continue; // lost a race: re-read and take the grace path
      return this.result(s.user, { ...s, expiresAt: this.refreshExpiry(now) }, next);
    }
    throw sessionRevoked();
  }

  async logout(user: AuthUser) { await this.revokeById(user.sessionId, 'logout'); }

  async logoutAll(user: AuthUser) {
    const live = await this.prisma.userSession.findMany({ where: { userId: user.id, revokedAt: null }, select: { id: true } });
    await this.prisma.userSession.updateMany({ where: { id: { in: live.map((s) => s.id) } }, data: { revokedAt: new Date(), revokedReason: 'logout_all' } });
    this.sessionAuth.invalidateSessions(live.map((s) => s.id));
    return { revoked: live.length };
  }

  async listSessions(user: AuthUser) {
    const rows = await this.prisma.userSession.findMany({ where: { userId: user.id, revokedAt: null, expiresAt: { gt: new Date() } }, orderBy: { lastUsedAt: 'desc' } });
    return rows.map((s) => ({ id: s.id, current: s.id === user.sessionId, createdAt: s.createdAt.toISOString(), lastUsedAt: s.lastUsedAt.toISOString(), ip: s.ip, device: { name: s.deviceName, platform: s.platform, appVersion: s.appVersion } }));
  }

  async revokeOwn(user: AuthUser, sessionId: string) {
    const s = await this.prisma.userSession.findFirst({ where: { id: sessionId, userId: user.id, revokedAt: null } });
    if (!s) throw notFound('Session');
    await this.revokeById(s.id, 'revoked_by_user');
  }

  async me(user: AuthUser): Promise<MeDto> {
    const u = await this.prisma.user.findUnique({ where: { id: user.id }, include: { workerProfile: { select: { id: true } } } });
    if (!u) throw notFound('User');
    return { id: u.id, fullName: u.fullName, phone: u.phone, role: u.role as Role, workerId: u.workerProfile?.id ?? null, permissions: user.permissions };
  }

  /** ADMIN unlocks a phone after a login lockout (a synthetic success row resets the failure counter). */
  async unlockPhone(phone: string) { await this.attempt(phone, undefined, true, 'admin_unlock'); }

  async revokeById(sessionId: string, reason: string) {
    await this.prisma.userSession.updateMany({ where: { id: sessionId, revokedAt: null }, data: { revokedAt: new Date(), revokedReason: reason } });
    this.sessionAuth.invalidateSessions([sessionId]);
  }
  async revokeAllOf(userId: string, reason: string) {
    const live = await this.prisma.userSession.findMany({ where: { userId, revokedAt: null }, select: { id: true } });
    await this.prisma.userSession.updateMany({ where: { id: { in: live.map((s) => s.id) } }, data: { revokedAt: new Date(), revokedReason: reason } });
    this.sessionAuth.invalidateSessions(live.map((s) => s.id));
  }

  // ---- internals -----------------------------------------------------------------------------------------------------
  /** Brute-force protection, uniform for existing and unknown phones. */
  private async assertNotThrottled(phone: string, ip?: string) {
    const since = new Date(Date.now() - this.env.LOGIN_LOCK_MINUTES * MIN);
    const lastOk = await this.prisma.loginAttempt.findFirst({ where: { phone, success: true, createdAt: { gt: since } }, orderBy: { createdAt: 'desc' }, select: { createdAt: true } });
    const failures = await this.prisma.loginAttempt.count({ where: { phone, success: false, createdAt: { gt: lastOk?.createdAt ?? since } } });
    if (failures >= this.env.LOGIN_MAX_FAILURES) throw rateLimited(this.env.LOGIN_LOCK_MINUTES * 60);
    if (ip && (await this.prisma.loginAttempt.count({ where: { ip, success: false, createdAt: { gt: since } } })) >= this.env.LOGIN_MAX_FAILURES * 6) throw rateLimited(this.env.LOGIN_LOCK_MINUTES * 60);
  }
  private attempt(phone: string, ip: string | undefined, success: boolean, reason: string) {
    return this.prisma.loginAttempt.create({ data: { phone, ip, success, reason } });
  }
  private refreshExpiry(from: Date) { return new Date(from.getTime() + this.env.REFRESH_TOKEN_TTL_DAYS * 24 * 60 * MIN); }

  private async result(user: User, session: Pick<UserSession, 'id' | 'expiresAt'>, refreshToken: string): Promise<AuthResult> {
    const accessToken = await this.jwt.signAsync({ sub: user.id, role: user.role, sid: session.id });
    const profile = await this.prisma.workerProfile.findUnique({ where: { userId: user.id }, select: { id: true } });
    return {
      accessToken, accessTokenExpiresAt: new Date(Date.now() + this.env.ACCESS_TOKEN_TTL_SECONDS * 1000).toISOString(),
      refreshToken, refreshTokenExpiresAt: session.expiresAt.toISOString(),
      user: { id: user.id, fullName: user.fullName, phone: user.phone, role: user.role as Role, workerId: profile?.id ?? null, permissions: await this.sessionAuth.permissionsOf(user.id, user.role as Role) },
    };
  }
}
