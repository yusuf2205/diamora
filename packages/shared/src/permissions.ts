import type { Role } from './basics';

/**
 * Permission model (D-028, docs/RBAC.md). A ROLE gives a default set; SUPER_ADMIN always has everything; ADMIN and MANAGER can be
 * given extra permissions or have defaults taken away per user (table user_permissions). WORKER is fixed. Checked SERVER-SIDE only.
 */
export const PERMISSIONS = [
  'USER_VIEW_ALL', 'USER_CREATE', 'USER_UPDATE', 'USER_DEACTIVATE', 'ROLE_ASSIGN', 'PERMISSION_MANAGE',
  'WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED', 'WORKER_APPROVE', 'WORKER_UPDATE', 'WORKER_ASSIGN_MANAGER',
  'COLLATERAL_VIEW', 'COLLATERAL_MANAGE',
  'ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_VIEW_ASSIGNED', 'ASSIGNMENT_CREATE', 'ASSIGNMENT_ACCEPT',
  'FINANCE_VIEW_ALL', 'FINANCE_VIEW_ASSIGNED', 'CASH_PAYOUT', 'PROFIT_VIEW',
  'CATALOG_VIEW', 'CATALOG_MANAGE',
  'INVENTORY_VIEW', 'INVENTORY_MANAGE',
  'MAP_VIEW_ALL', 'MAP_VIEW_ASSIGNED',
  'LIVE_LOCATION_VIEW_ALL', 'LIVE_LOCATION_VIEW_ASSIGNED',
  'PAY_RATE_MANAGE', 'SETTINGS_MANAGE', 'AUDIT_VIEW',
] as const;
export type Permission = (typeof PERMISSIONS)[number];
export const isPermission = (v: string): v is Permission => (PERMISSIONS as readonly string[]).includes(v);

/** Never grantable to anyone but SUPER_ADMIN: control over roles and over permissions themselves. */
export const SUPER_ADMIN_ONLY: readonly Permission[] = ['ROLE_ASSIGN', 'PERMISSION_MANAGE'];

const ADMIN_DEFAULTS: readonly Permission[] = [
  'USER_VIEW_ALL', 'WORKER_VIEW_ALL', 'WORKER_APPROVE', 'WORKER_UPDATE', 'COLLATERAL_VIEW', 'COLLATERAL_MANAGE',
  'ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_CREATE', 'ASSIGNMENT_ACCEPT', 'FINANCE_VIEW_ALL', 'CASH_PAYOUT', 'PROFIT_VIEW',
  'CATALOG_VIEW', 'CATALOG_MANAGE', 'INVENTORY_VIEW', 'INVENTORY_MANAGE', 'MAP_VIEW_ALL', 'LIVE_LOCATION_VIEW_ALL',
];
const MANAGER_DEFAULTS: readonly Permission[] = [
  'WORKER_VIEW_ASSIGNED', 'ASSIGNMENT_VIEW_ASSIGNED', 'FINANCE_VIEW_ASSIGNED', 'MAP_VIEW_ASSIGNED', 'LIVE_LOCATION_VIEW_ASSIGNED',
];
/** What an ADMIN can be given on top of the defaults: everything except SUPER_ADMIN_ONLY and the manager-scoped variants. */
export const ADMIN_GRANTABLE: readonly Permission[] = PERMISSIONS.filter(
  (p) => !SUPER_ADMIN_ONLY.includes(p) && !p.endsWith('_ASSIGNED'),
);
/** A MANAGER stays inside their own workers: only these can be granted (never *_ALL, users, roles, settings, audit, pay rate). */
export const MANAGER_GRANTABLE: readonly Permission[] = [
  'COLLATERAL_VIEW', 'COLLATERAL_MANAGE', 'ASSIGNMENT_CREATE', 'ASSIGNMENT_ACCEPT', 'CASH_PAYOUT', 'CATALOG_VIEW', 'INVENTORY_VIEW', 'WORKER_UPDATE',
];

export const ROLE_DEFAULT_PERMISSIONS: Record<Role, readonly Permission[]> = {
  SUPER_ADMIN: PERMISSIONS,
  ADMIN: ADMIN_DEFAULTS,
  MANAGER: MANAGER_DEFAULTS,
  WORKER: [],
};

export interface PermissionOverride { permission: string; granted: boolean }

export function grantablePermissions(role: Role): readonly Permission[] {
  if (role === 'ADMIN') return ADMIN_GRANTABLE;
  if (role === 'MANAGER') return MANAGER_GRANTABLE;
  return [];
}

/** role defaults + explicit grants - explicit revokes. SUPER_ADMIN always has all; WORKER ignores overrides. */
export function effectivePermissions(role: Role, overrides: readonly PermissionOverride[] = []): Permission[] {
  if (role === 'SUPER_ADMIN') return [...PERMISSIONS];
  if (role === 'WORKER') return [];
  const set = new Set<Permission>(ROLE_DEFAULT_PERMISSIONS[role]);
  const allowed = new Set(grantablePermissions(role));
  for (const o of overrides) {
    if (!isPermission(o.permission)) continue;
    if (o.granted) { if (allowed.has(o.permission) || set.has(o.permission)) set.add(o.permission); }
    else set.delete(o.permission);
  }
  return PERMISSIONS.filter((p) => set.has(p));
}

// ---- worker-scoped data (a MANAGER sees only their own workers) --------------------------------------------------------
/** A category of worker-related data: who sees ALL of it, and who sees only the workers assigned to them. */
export const WORKER_CATEGORIES = {
  WORKER: { all: ['WORKER_VIEW_ALL'], assigned: ['WORKER_VIEW_ASSIGNED'] },
  COLLATERAL: { all: ['WORKER_VIEW_ALL', 'COLLATERAL_VIEW'], assigned: ['WORKER_VIEW_ASSIGNED', 'COLLATERAL_VIEW'] },
  ASSIGNMENT: { all: ['ASSIGNMENT_VIEW_ALL'], assigned: ['ASSIGNMENT_VIEW_ASSIGNED'] },
  FINANCE: { all: ['FINANCE_VIEW_ALL'], assigned: ['FINANCE_VIEW_ASSIGNED'] },
  LOCATION: { all: ['LIVE_LOCATION_VIEW_ALL'], assigned: ['LIVE_LOCATION_VIEW_ASSIGNED'] },
  MAP: { all: ['MAP_VIEW_ALL'], assigned: ['MAP_VIEW_ASSIGNED'] },
} as const satisfies Record<string, { all: readonly Permission[]; assigned: readonly Permission[] }>;
export type WorkerCategory = keyof typeof WORKER_CATEGORIES;

export type Scope = 'all' | 'assigned' | 'none';
/** The single source of truth for "which workers may this user see in this category" (REST filters and realtime rooms both use it). */
export function scopeFor(perms: readonly Permission[], cat: WorkerCategory): Scope {
  const has = (need: readonly Permission[]) => need.every((p) => perms.includes(p));
  if (has(WORKER_CATEGORIES[cat].all)) return 'all';
  if (has(WORKER_CATEGORIES[cat].assigned)) return 'assigned';
  return 'none';
}
