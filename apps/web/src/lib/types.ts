// Shapes mirror the API DTOs (apps/api/src/**). Money is always a decimal STRING — never a float.

export interface Me {
  id: string;
  fullName: string;
  phone: string;
  role: 'SUPER_ADMIN' | 'ADMIN' | 'MANAGER' | 'WORKER';
  workerId: string | null;
  permissions: string[];
}

export function hasPerm(me: Me | null | undefined, ...perms: string[]): boolean {
  return !!me && perms.some((p) => me.permissions.includes(p));
}

export interface TeamUser {
  id: string;
  phone: string;
  fullName: string;
  role: Me['role'];
  status: 'ACTIVE' | 'SUSPENDED';
  online: boolean;
  lastLoginAt: string | null;
  lastSeenAt: string | null;
  workerId: string | null;
  permissions: string[];
}

export interface ManagerSummary extends TeamUser {
  stats: { workers: number; activeWorkers: number; activeAssignments: number; metersOnHand: number; toDeliver: number; toPickup: number; overdue: number; earned: string; paid: string; due: string };
}

export interface Worker {
  id: string;
  code: string;
  fullName: string;
  phone: string;
  secondaryPhone: string | null;
  status: 'PENDING_APPROVAL' | 'ACTIVE' | 'PAUSED' | 'REJECTED' | 'ARCHIVED';
  latitude: number | null;
  longitude: number | null;
  locationReceivedAt: string | null;
  balance: string;
  manager: { id: string; fullName: string } | null;
  collateral: { id: string; type: string; status: string; amount: string | null; description: string | null } | null;
  createdAt: string;
  updatedAt: string;
}

export interface CatalogFileRef { id: string; url: string; thumbUrl?: string }
export interface CatalogMedia { id: string; kind: 'PHOTO' | 'VIDEO'; isMain: boolean; caption: string | null; variantId: string | null; file: CatalogFileRef | null }
export interface CatalogVariant { id: string; label: string | null; active: boolean; color?: { id: string; name: string; hex: string | null } }
export interface CatalogItem {
  id: string;
  code: string;
  name: string;
  description: string | null;
  status: 'DRAFT' | 'PUBLISHED' | 'HIDDEN';
  availability: 'AVAILABLE' | 'ON_REQUEST' | 'UNAVAILABLE';
  isNew: boolean;
  sortOrder: number;
  media: CatalogMedia[];
  variants: CatalogVariant[];
}

export interface PayRate { ratePerKit: string; kitMeters: number; updatedAt: string }
export interface PayRateChange { id: string; ratePerKit: string; previousRatePerKit: string | null; changedBy: string | null; note: string | null; createdAt: string }
export interface CompanyContact { phone: string | null; telegramUsername: string | null; telegramUrl: string | null; updatedAt: string }
export interface AuditEntry { id: string; action: string; entity: string; entityId: string | null; actorId: string | null; actorRole: string | null; before: unknown; after: unknown; requestId: string | null; createdAt: string }
export interface LiveLocation {
  userId: string; role: Me['role']; fullName: string; phone: string | null; online: boolean;
  worker: { id: string; code: string; phone: string; managerId: string | null } | null;
  latitude: number; longitude: number; accuracy: number | null; recordedAt: string;
  ageSeconds: number; freshness: 'LIVE' | 'RECENT' | 'STALE'; stale: boolean; isBackground: boolean;
}

export interface Dashboard {
  workers: { total: number; active: number; pendingApproval: number; paused: number };
  users: { superAdmins: number; admins: number; managers: number; online: number };
  catalog: { published: number; draft: number };
  work: { activeAssignments: number; metersOnHand: number; toDeliver: number; toPickup: number; overdue: number };
  finance: { earned: string; paid: string; due: string; salesRevenue: string | null; expenses: string | null; netProfit: string | null };
  inventory: { lowStockMaterials: number };
}

export interface Page<T> { items: T[]; nextCursor?: string | null }
