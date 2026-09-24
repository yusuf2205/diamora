import { Controller, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Patch, Post, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Prisma, User, UserPermission } from '@yusmus/database';
import {
  PERMISSIONS, ROLE_DEFAULT_PERMISSIONS, ROLE_RANK, SUPER_ADMIN_ONLY, changeRoleSchema, createUserSchema, effectivePermissions,
  grantablePermissions, listUsersSchema, setPermissionsSchema, setUserStatusSchema, updateUserSchema, type Permission, type Role,
} from '@yusmus/shared';
import { randomInt } from 'node:crypto';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { PasswordService, SessionAuthService } from '../auth/auth-core';
import { AuthService } from '../auth/auth.service';
import { ApiZodBody, CurrentUser, Perm } from '../common/decorators';
import { conflict, forbidden, invariant, notFound, validationFailed } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { PrismaService } from '../prisma/prisma.module';
import { PresenceModule, PresenceService } from '../presence/presence.service';
import { StatsModule, StatsService } from '../stats/stats.service';

const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
const generatePassword = () => Array.from({ length: 14 }, () => ALPHABET[randomInt(ALPHABET.length)]).join('');
type Tx = Prisma.TransactionClient;
type UserWithPerms = User & { permissions: UserPermission[]; workerProfile?: { id: string; assignedManagerId: string | null; assignedManager?: { fullName: string } | null } | null };

/**
 * Users, roles, permissions (D-028, docs/RBAC.md). Rules enforced here (server-side, whatever the client sends):
 *  - a user may only manage users of a strictly LOWER rank (SUPER_ADMIN manages everybody);
 *  - ROLE_ASSIGN / PERMISSION_MANAGE exist only for SUPER_ADMIN; nobody changes their own role, status or permissions;
 *  - there is always at least one ACTIVE SUPER_ADMIN;
 *  - users are deactivated, never deleted (financial and audit history keeps pointing at them);
 *  - WORKER accounts are created only by the Telegram registration (their identity is Telegram).
 */
@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly passwords: PasswordService,
    private readonly sessions: SessionAuthService, private readonly auth: AuthService, private readonly events: EventBus,
    private readonly presence: PresenceService, private readonly stats: StatsService,
  ) {}

  // ---- reads ----------------------------------------------------------------------------------------------------------------
  async list(q: z.output<typeof listUsersSchema>) {
    const text = q.q?.trim();
    const digits = text?.replace(/\D/g, '');
    const rows = await this.prisma.user.findMany({
      where: {
        role: q.role, status: q.status,
        OR: text ? [{ fullName: { contains: text, mode: 'insensitive' } }, ...(digits && digits.length >= 3 ? [{ phone: { contains: digits } }] : [])] : undefined,
      },
      include: { permissions: true, workerProfile: { select: { id: true, assignedManagerId: true, assignedManager: { select: { fullName: true } } } } },
      orderBy: { id: 'desc' }, take: q.limit + 1, ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
    });
    const items = rows.slice(0, q.limit);
    return { items: items.map((u) => this.dto(u)), nextCursor: rows.length > q.limit ? items[items.length - 1].id : null };
  }

  async get(id: string) {
    const u = await this.load(this.prisma, id);
    return { ...this.dto(u), permissionDetail: this.permissionDetail(u), manager: u.workerProfile?.assignedManagerId ? await this.brief(u.workerProfile.assignedManagerId) : null };
  }

  /** What the UI needs to render the permission editor: every permission, role defaults, what may be granted. */
  catalog() {
    return {
      permissions: [...PERMISSIONS], superAdminOnly: [...SUPER_ADMIN_ONLY],
      roleDefaults: ROLE_DEFAULT_PERMISSIONS, grantable: { ADMIN: grantablePermissions('ADMIN'), MANAGER: grantablePermissions('MANAGER') },
    };
  }

  // ---- writes ---------------------------------------------------------------------------------------------------------------
  async create(actor: AuthUser, input: z.output<typeof createUserSchema>) {
    if (actor.role !== 'SUPER_ADMIN' && ROLE_RANK[input.role] >= ROLE_RANK[actor.role]) throw forbidden('You cannot create a user with this role');
    const password = input.password ?? generatePassword();
    const passwordHash = await this.passwords.hash(password);
    const user = await this.prisma.$transaction(async (tx) => {
      await this.lockSuperAdmins(tx);
      if (await tx.user.findUnique({ where: { phone: input.phone }, select: { id: true } })) throw conflict('A user with this phone already exists');
      if (await tx.workerProfile.findUnique({ where: { phone: input.phone }, select: { id: true } })) throw conflict('This phone belongs to a worker');
      const u = await tx.user.create({ data: { phone: input.phone, fullName: input.fullName, role: input.role, passwordHash }, include: { permissions: true } });
      await this.audit.record({ action: 'user.create', entity: 'User', entityId: u.id, after: { role: u.role, phone: u.phone, fullName: u.fullName } }, tx);
      return u;
    });
    await this.events.publish('user.created', { userId: user.id, role: user.role as Role, fullName: user.fullName });
    return { user: this.dto(user), ...(input.password ? {} : { temporaryPassword: password }) };
  }

  async update(actor: AuthUser, id: string, patch: z.output<typeof updateUserSchema>) {
    const before = await this.load(this.prisma, id);
    this.assertMayManage(actor, before, { allowSelf: true });
    if (patch.phone && patch.phone !== before.phone) {
      if (before.role === 'WORKER') throw invariant('A worker phone is changed on the worker card');
      if (await this.prisma.user.findFirst({ where: { phone: patch.phone, id: { not: id } }, select: { id: true } })) throw conflict('A user with this phone already exists');
    }
    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({ where: { id }, data: patch });
      await this.audit.record({ action: 'user.update', entity: 'User', entityId: id, before: { fullName: before.fullName, phone: before.phone }, after: patch }, tx);
    });
    if (patch.phone && patch.phone !== before.phone) await this.auth.revokeAllOf(id, 'phone_changed');
    await this.events.publish('user.updated', { userId: id });
    return this.get(id);
  }

  async setStatus(actor: AuthUser, id: string, input: z.output<typeof setUserStatusSchema>) {
    await this.prisma.$transaction(async (tx) => {
      await this.lockSuperAdmins(tx);
      const before = await this.load(tx, id);
      this.assertMayManage(actor, before, { allowSelf: false });
      if (before.status === input.status) return;
      if (input.status === 'SUSPENDED') await this.assertNotLastSuperAdmin(tx, before);
      await tx.user.update({ where: { id }, data: { status: input.status } });
      await this.audit.record({ action: input.status === 'SUSPENDED' ? 'user.deactivate' : 'user.reactivate', entity: 'User', entityId: id, before: { status: before.status }, after: { status: input.status, reason: input.reason } }, tx);
    });
    if (input.status === 'SUSPENDED') await this.auth.revokeAllOf(id, 'user_deactivated');
    await this.sessions.refreshUser(id);
    await this.events.publish('user.updated', { userId: id });
    return this.get(id);
  }

  async changeRole(actor: AuthUser, id: string, input: z.output<typeof changeRoleSchema>) {
    let from: Role = 'ADMIN';
    await this.prisma.$transaction(async (tx) => {
      await this.lockSuperAdmins(tx);
      const before = await this.load(tx, id);
      this.assertMayManage(actor, before, { allowSelf: false });
      if (before.role === 'WORKER') throw invariant('A worker cannot become staff: workers are created by the Telegram registration');
      from = before.role as Role;
      if (from === input.role) return;
      if (from === 'SUPER_ADMIN') await this.assertNotLastSuperAdmin(tx, before);
      if (from === 'MANAGER') {
        const n = await tx.workerProfile.count({ where: { assignedManagerId: id } });
        if (n > 0) throw invariant(`This manager still has ${n} worker(s): assign them to another manager first`, { workers: n });
      }
      await tx.user.update({ where: { id }, data: { role: input.role } });
      // overrides that make no sense for the new role are dropped with it
      const keep = new Set<string>([...grantablePermissions(input.role), ...ROLE_DEFAULT_PERMISSIONS[input.role]]);
      await tx.userPermission.deleteMany({ where: { userId: id, permission: { notIn: [...keep] } } });
      await this.audit.record({ action: 'user.role_change', entity: 'User', entityId: id, before: { role: from }, after: { role: input.role } }, tx);
    });
    if (from !== input.role) {
      await this.auth.revokeAllOf(id, 'role_changed'); // fresh login = fresh role everywhere (tokens, sockets, caches)
      await this.events.publish('user.role_changed', { userId: id, from, to: input.role });
    }
    return this.get(id);
  }

  async setPermissions(actor: AuthUser, id: string, input: z.output<typeof setPermissionsSchema>) {
    await this.prisma.$transaction(async (tx) => {
      const target = await this.load(tx, id);
      this.assertMayManage(actor, target, { allowSelf: false });
      const role = target.role as Role;
      if (role !== 'ADMIN' && role !== 'MANAGER') throw invariant('Permissions can be adjusted for ADMIN and MANAGER only (SUPER_ADMIN has all, WORKER has a fixed set)');
      const defaults = new Set<Permission>(ROLE_DEFAULT_PERMISSIONS[role]);
      const allowed = new Set(grantablePermissions(role));
      const bad = input.grant.filter((p) => !defaults.has(p) && !allowed.has(p));
      if (bad.length) throw validationFailed(`These permissions cannot be granted to a ${role}: ${bad.join(', ')}`, { permissions: bad });
      const rows = [
        ...input.grant.filter((p) => !defaults.has(p)).map((permission) => ({ userId: id, permission, granted: true, createdById: actor.id })),
        ...input.revoke.filter((p) => defaults.has(p) && !input.grant.includes(p)).map((permission) => ({ userId: id, permission, granted: false, createdById: actor.id })),
      ];
      const beforeEff = effectivePermissions(role, target.permissions);
      await tx.userPermission.deleteMany({ where: { userId: id } });
      if (rows.length) await tx.userPermission.createMany({ data: rows });
      const afterEff = effectivePermissions(role, rows);
      await this.audit.record({ action: 'user.permission_change', entity: 'User', entityId: id, before: { effective: beforeEff }, after: { grant: input.grant, revoke: input.revoke, effective: afterEff } }, tx);
    });
    await this.sessions.refreshUser(id);
    await this.events.publish('user.permission_changed', { userId: id });
    return this.get(id);
  }

  async resetPassword(actor: AuthUser, id: string) {
    const target = await this.load(this.prisma, id);
    this.assertMayManage(actor, target, { allowSelf: false });
    if (target.role === 'WORKER') throw invariant('Workers sign in with a Telegram code, they have no password');
    const password = generatePassword();
    const passwordHash = await this.passwords.hash(password);
    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({ where: { id }, data: { passwordHash } });
      await this.audit.record({ action: 'user.password_reset', entity: 'User', entityId: id }, tx);
    });
    await this.auth.revokeAllOf(id, 'password_reset');
    return { temporaryPassword: password };
  }

  // ---- managers ---------------------------------------------------------------------------------------------------------------
  async managers(viewer: AuthUser) {
    const managers = await this.prisma.user.findMany({
      where: { role: 'MANAGER', ...(viewer.permissions.includes('USER_VIEW_ALL') ? {} : { id: viewer.id }) },
      include: { permissions: true, liveLocation: true, workerProfile: { select: { id: true, assignedManagerId: true } } },
      orderBy: { fullName: 'asc' },
    });
    const items = [];
    for (const m of managers) items.push(await this.managerRow(m));
    return { items };
  }

  async managerDetail(id: string) {
    const m = await this.prisma.user.findFirst({ where: { id, role: 'MANAGER' }, include: { permissions: true, liveLocation: true, workerProfile: { select: { id: true, assignedManagerId: true } } } });
    if (!m) throw notFound('Manager');
    const workers = await this.prisma.workerProfile.findMany({ where: { assignedManagerId: id }, select: { id: true, code: true, fullName: true, phone: true, status: true, userId: true }, orderBy: { fullName: 'asc' } });
    const per = await this.stats.perWorker(workers.map((w) => w.id));
    return {
      ...(await this.managerRow(m)),
      workers: workers.map((w) => ({ ...w, online: w.userId ? this.presence.isOnline(w.userId) : false, ...(per.get(w.id) ?? {}) })),
    };
  }

  private async managerRow(m: UserWithPerms & { liveLocation: { latitude: number; longitude: number; recordedAt: Date } | null }) {
    return {
      ...this.dto(m),
      online: this.presence.isOnline(m.id),
      location: m.liveLocation ? { latitude: m.liveLocation.latitude, longitude: m.liveLocation.longitude, recordedAt: m.liveLocation.recordedAt.toISOString() } : null,
      stats: await this.stats.forWorkers({ assignedManagerId: m.id }),
    };
  }

  // ---- internals ---------------------------------------------------------------------------------------------------------------
  private async load(db: PrismaService | Tx, id: string): Promise<UserWithPerms> {
    const u = await db.user.findUnique({ where: { id }, include: { permissions: true, workerProfile: { select: { id: true, assignedManagerId: true } } } });
    if (!u) throw notFound('User');
    return u;
  }
  private async brief(id: string) {
    const u = await this.prisma.user.findUnique({ where: { id }, select: { id: true, fullName: true, phone: true } });
    return u;
  }

  /** Rank rule: strictly lower rank than the actor (SUPER_ADMIN: anybody), and never yourself unless explicitly allowed. */
  private assertMayManage(actor: AuthUser, target: User, opts: { allowSelf: boolean }) {
    if (actor.id === target.id) { if (opts.allowSelf) return; throw forbidden('You cannot change your own role, status or permissions'); }
    if (actor.role === 'SUPER_ADMIN') return;
    if (ROLE_RANK[target.role as Role] >= ROLE_RANK[actor.role]) throw forbidden('You cannot manage a user of this rank');
  }
  /** Serialises everything that can change the set of active super admins. */
  private lockSuperAdmins(tx: Tx) { return tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('yusmus:super_admins'))`; }
  private async assertNotLastSuperAdmin(tx: Tx, target: User) {
    if (target.role !== 'SUPER_ADMIN' || target.status !== 'ACTIVE') return;
    const others = await tx.user.count({ where: { role: 'SUPER_ADMIN', status: 'ACTIVE', id: { not: target.id } } });
    if (others === 0) throw invariant('There must always be at least one active SUPER_ADMIN');
  }

  private permissionDetail(u: UserWithPerms) {
    const role = u.role as Role;
    return {
      role, defaults: [...ROLE_DEFAULT_PERMISSIONS[role]], effective: effectivePermissions(role, u.permissions),
      granted: u.permissions.filter((p) => p.granted).map((p) => p.permission), revoked: u.permissions.filter((p) => !p.granted).map((p) => p.permission),
    };
  }
  private dto(u: UserWithPerms) {
    return {
      id: u.id, phone: u.phone, fullName: u.fullName, role: u.role as Role, status: u.status,
      lastLoginAt: u.lastLoginAt?.toISOString() ?? null, lastSeenAt: u.lastSeenAt?.toISOString() ?? null, createdAt: u.createdAt.toISOString(),
      workerId: u.workerProfile?.id ?? null, managerName: u.workerProfile?.assignedManager?.fullName ?? null, online: this.presence.isOnline(u.id), permissions: effectivePermissions(u.role as Role, u.permissions),
    };
  }
}

@ApiTags('users')
@ApiBearerAuth()
@Controller()
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Perm('USER_VIEW_ALL') @Get('users')
  list(@ZodQuery(listUsersSchema) q: z.output<typeof listUsersSchema>) { return this.users.list(q); }

  @Perm('USER_VIEW_ALL', 'PERMISSION_MANAGE') @Get('permissions')
  catalog() { return this.users.catalog(); }

  @Perm('USER_VIEW_ALL') @Get('users/:id')
  get(@Param('id', new ParseUUIDPipe()) id: string) { return this.users.get(id); }

  @Perm('USER_CREATE') @Post('users') @ApiZodBody(createUserSchema)
  create(@CurrentUser() u: AuthUser, @ZodBody(createUserSchema) b: z.output<typeof createUserSchema>) { return this.users.create(u, b); }

  @Perm('USER_UPDATE') @Patch('users/:id') @ApiZodBody(updateUserSchema)
  update(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(updateUserSchema) b: z.output<typeof updateUserSchema>) { return this.users.update(u, id, b); }

  @Perm('USER_DEACTIVATE') @Post('users/:id/status') @HttpCode(200) @ApiZodBody(setUserStatusSchema)
  status(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(setUserStatusSchema) b: z.output<typeof setUserStatusSchema>) { return this.users.setStatus(u, id, b); }

  @Perm('ROLE_ASSIGN') @Put('users/:id/role') @ApiZodBody(changeRoleSchema)
  role(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(changeRoleSchema) b: z.output<typeof changeRoleSchema>) { return this.users.changeRole(u, id, b); }

  @Perm('PERMISSION_MANAGE') @Put('users/:id/permissions') @ApiZodBody(setPermissionsSchema)
  permissions(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(setPermissionsSchema) b: z.output<typeof setPermissionsSchema>) { return this.users.setPermissions(u, id, b); }

  @Perm('USER_UPDATE') @Post('users/:id/reset-password') @HttpCode(200)
  reset(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.users.resetPassword(u, id); }

  @Perm('USER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED') @Get('managers')
  managers(@CurrentUser() u: AuthUser) { return this.users.managers(u); }

  @Perm('USER_VIEW_ALL') @Get('managers/:id')
  manager(@Param('id', new ParseUUIDPipe()) id: string) { return this.users.managerDetail(id); }
}

@Module({ imports: [PresenceModule, StatsModule], controllers: [UsersController], providers: [UsersService], exports: [UsersService] })
export class UsersModule {}
