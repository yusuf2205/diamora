import { CanActivate, ExecutionContext, Injectable, Logger } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import type { Role } from '@yusmus/shared';
import * as argon2 from 'argon2';
import type { Request } from 'express';
import { randomBytes, randomInt } from 'node:crypto';
import { IS_AUTHENTICATED, IS_PUBLIC, ROLES_KEY } from '../common/decorators';
import { forbidden, sessionRevoked, unauthenticated } from '../common/errors';
import { RequestContext, type AuthUser } from '../common/request-context';
import { PrismaService } from '../prisma/prisma.module';

const ARGON: argon2.HashOptions = { type: argon2.argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1 }; // OWASP minimum, NAS-friendly

@Injectable()
export class PasswordService {
  private dummy?: Promise<string>;
  hash(plain: string) { return argon2.hash(plain, ARGON); }
  async verify(hash: string, plain: string) { try { return await argon2.verify(hash, plain); } catch { return false; } }
  /** Burns the CPU time of a real verification so unknown phones cannot be told apart by timing. */
  async verifyDummy(plain: string) { this.dummy ??= this.hash(randomBytes(16).toString('hex')); await this.verify(await this.dummy, plain); }
}

const CACHE_MS = 5_000;

/** Resolves a token's session id to a live principal from the DB (revocations/suspensions apply at once; 5 s cache). */
@Injectable()
export class SessionAuthService {
  private readonly cache = new Map<string, { user: AuthUser | null; expires: number }>();
  private readonly revokedHandlers: Array<(ids: string[]) => void> = [];
  constructor(private readonly prisma: PrismaService) {}

  async resolve(sessionId: string): Promise<AuthUser | null> {
    const now = Date.now();
    const hit = this.cache.get(sessionId);
    if (hit && hit.expires > now) return hit.user;
    const s = await this.prisma.userSession.findUnique({
      where: { id: sessionId },
      select: { id: true, revokedAt: true, expiresAt: true, user: { select: { id: true, role: true, status: true, fullName: true, workerProfile: { select: { id: true } } } } },
    });
    const valid = !!s && !s.revokedAt && s.expiresAt.getTime() > now && s.user.status === 'ACTIVE';
    const user: AuthUser | null = valid
      ? { id: s.user.id, role: s.user.role as Role, fullName: s.user.fullName, sessionId: s.id, workerId: s.user.workerProfile?.id ?? null }
      : null;
    this.cache.set(sessionId, { user, expires: now + CACHE_MS });
    if (this.cache.size > 5000) for (const [k, v] of this.cache) if (v.expires <= now) this.cache.delete(k);
    return user;
  }
  onRevoked(h: (ids: string[]) => void) { this.revokedHandlers.push(h); }
  invalidateSessions(ids: string[]) { for (const id of ids) this.cache.delete(id); if (ids.length) this.revokedHandlers.forEach((h) => h(ids)); }
  invalidateAll() { const ids = [...this.cache.keys()]; this.cache.clear(); if (ids.length) this.revokedHandlers.forEach((h) => h(ids)); }
}

export const randomCode6 = () => String(randomInt(0, 1_000_000)).padStart(6, '0');

// ---- guards ------------------------------------------------------------------------------------------------------
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly reflector: Reflector, private readonly jwt: JwtService, private readonly sessions: SessionAuthService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, [ctx.getHandler(), ctx.getClass()])) return true;
    const req = ctx.switchToHttp().getRequest<Request>();
    const h = req.headers.authorization;
    if (!h?.startsWith('Bearer ')) throw unauthenticated();
    let sid: string | undefined;
    try { sid = (await this.jwt.verifyAsync<{ sid?: string }>(h.slice(7), { algorithms: ['HS256'] })).sid; } catch { throw unauthenticated('Invalid or expired access token'); }
    if (!sid) throw unauthenticated('Invalid access token');
    const user = await this.sessions.resolve(sid);
    if (!user) throw sessionRevoked();
    req.user = user;
    RequestContext.setUser(user);
    return true;
  }
}

/** DENY BY DEFAULT: a route must declare @Public, @Authenticated or @Roles (a test enumerates all routes). */
@Injectable()
export class RolesGuard implements CanActivate {
  private readonly log = new Logger('RolesGuard');
  constructor(private readonly reflector: Reflector) {}
  canActivate(ctx: ExecutionContext): boolean {
    const t = [ctx.getHandler(), ctx.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, t)) return true;
    const user = ctx.switchToHttp().getRequest<Request>().user;
    if (!user) throw unauthenticated();
    const roles = this.reflector.getAllAndOverride<Role[] | undefined>(ROLES_KEY, t);
    if (roles) {
      if (!roles.includes(user.role)) throw forbidden();
      return true;
    }
    if (this.reflector.getAllAndOverride<boolean>(IS_AUTHENTICATED, t)) return true;
    this.log.error(`Route ${ctx.getClass().name}.${ctx.getHandler().name} has no access declaration — denied`);
    throw forbidden();
  }
}
