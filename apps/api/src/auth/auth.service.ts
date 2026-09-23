import { Inject, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { User, UserSession } from '@yusmus/database';
import { isStaffRole, type Permission, type Role } from '@yusmus/shared';
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { AuditService } from '../audit/audit.service';
import { accountDisabled, AppError, invalidCode, invalidCredentials, notFound, rateLimited, sessionRevoked, unauthenticated, userNotFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { ENV, Env } from '../config/env';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.module';
import { PasswordService, SessionAuthService, randomCode6 } from './auth-core';

export interface ClientMeta { ip?: string; userAgent?: string }
export interface DeviceInput { installId: string; platform: string; name?: string; appVersion?: string }
export interface MeDto { id: string; fullName: string; phone: string; role: Role; workerId: string | null; permissions: Permission[] }
export interface AuthResult { accessToken: string; accessTokenExpiresAt: string; refreshToken: string; refreshTokenExpiresAt: string; user: MeDto }

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
    private readonly notifications: NotificationsService,
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
   * phone, tells the client which second field to show next. WORKER: the code is requested here so the client can go
   * straight to "enter code" without a second round trip. Never reveals staff vs worker beyond the method needed.
   */
  async identify(phone: string, meta: ClientMeta): Promise<{ method: 'PASSWORD' | 'CODE' }> {
    await this.assertNotThrottled(phone, meta.ip);
    const user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user) throw userNotFound();
    if (user.status !== 'ACTIVE') throw accountDisabled();
    if (isStaffRole(user.role)) return { method: 'PASSWORD' };
    await this.requestWorkerCode(phone, meta);
    return { method: 'CODE' };
  }

  // ---- WORKER: one-time code delivered by the Telegram bot -----------------------------------------------------------
  /** Always answers "sent" (no phone enumeration). A code is only created for an approved worker with an account. */
  async requestWorkerCode(phone: string, meta: ClientMeta): Promise<{ sent: true }> {
    await this.assertNotThrottled(phone, meta.ip);
    const worker = await this.prisma.workerProfile.findUnique({ where: { phone } });
    if (worker?.userId && (worker.status === 'ACTIVE' || worker.status === 'PAUSED')) {
      const recent = await this.prisma.loginCode.count({ where: { workerId: worker.id, createdAt: { gt: new Date(Date.now() - 10 * MIN) } } });
      if (recent < 3) {
        const code = randomCode6();
        await this.prisma.$transaction(async (tx) => {
          await tx.loginCode.create({ data: { workerId: worker.id, codeHash: this.codeHash(worker.id, code), expiresAt: new Date(Date.now() + this.env.LOGIN_CODE_TTL_MINUTES * MIN) } });
          await this.notifications.telegram({ workerId: worker.id, chatId: worker.telegramChatId, type: 'login_code', body: `Ваш код входа в приложение: ${code}\nДействует ${this.env.LOGIN_CODE_TTL_MINUTES} минут. Никому не сообщайте его.` }, tx);
        });
      }
    }
    return { sent: true };
  }

  async workerLogin(input: { phone: string; code: string; device: DeviceInput }, meta: ClientMeta): Promise<AuthResult> {
    await this.assertNotThrottled(input.phone, meta.ip);
    const worker = await this.prisma.workerProfile.findUnique({ where: { phone: input.phone }, include: { user: true } });
    const codeRow = worker?.user
      ? await this.prisma.loginCode.findFirst({ where: { workerId: worker.id, usedAt: null, expiresAt: { gt: new Date() } }, orderBy: { createdAt: 'desc' } })
      : null;
    let ok = false;
    if (worker && codeRow && codeRow.attempts < this.env.LOGIN_CODE_MAX_ATTEMPTS) {
      const a = Buffer.from(codeRow.codeHash);
      const b = Buffer.from(this.codeHash(worker.id, input.code));
      ok = a.length === b.length && timingSafeEqual(a, b);
      if (!ok) await this.prisma.loginCode.update({ where: { id: codeRow.id }, data: { attempts: { increment: 1 } } });
    }
    if (!worker?.user || !codeRow || !ok) {
      await this.attempt(input.phone, meta.ip, false, 'bad_code');
      throw invalidCode();
    }
    // single use: compare-and-set
    const used = await this.prisma.loginCode.updateMany({ where: { id: codeRow.id, usedAt: null }, data: { usedAt: new Date() } });
    if (used.count !== 1) throw invalidCode();
    if (worker.user.status !== 'ACTIVE') throw accountDisabled();
    await this.attempt(input.phone, meta.ip, true, 'login');
    return this.createSession(worker.user, input.device, meta);
  }

  private codeHash(workerId: string, code: string) { return sha256(`${workerId}:${code}:${this.env.JWT_ACCESS_SECRET}`); }

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
