// Shapes mirror the API DTOs (apps/api/src/**). Money is always a decimal STRING — never a float.

export interface Me {
  id: string;
  fullName: string;
  phone: string;
  role: 'SUPER_ADMIN' | 'ADMIN' | 'MANAGER' | 'WORKER';
  workerId: string | null;
  permissions: string[];
}

export interface UserDetail extends TeamUser {
  permissionDetail: { role: Me['role']; defaults: string[]; effective: string[]; granted: string[]; revoked: string[] };
}

export interface PermissionCatalog {
  permissions: string[];
  roleDefaults: Record<string, string[]>;
  grantable: Record<string, string[]>;
}

export interface AuditRow { id: string; action: string; entity: string; entityId: string | null; actorRole: string | null; createdAt: string }

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
  createdAt?: string;
  managerName?: string | null;
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
  rejectedReason?: string | null; // detail only
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

// Every section is `null` when the viewer lacks the permission to see it (never a fabricated zero, never a 403 for
// the whole endpoint over one out-of-reach section) — apps/api/src/stats/dashboard.controller.ts.
export interface Dashboard {
  workers: { total: number; active: number; withActiveAssignment: number; withoutActiveAssignment: number } | null;
  users: { superAdmins: number; admins: number; managers: number; online: number } | null;
  catalog: { published: number; draft: number } | null;
  work: { activeAssignments: number; inProgress: number; metersOnHand: number; toDeliver: number; toPickup: number; needsAcceptance: number; completed: number; overdue: number; reworkRequired?: number } | null;
  finance: { earned: string; paid: string; due: string; salesRevenue: string | null; expenses: string | null; netProfit: string | null; workersDue?: number } | null;
  materials: { lowStock: number; outOfStock: number } | null;
  today?: { dueToday: number | null; deliveredToday: number | null; pickedUpToday: number | null; paidToday: string | null };
}

export interface Page<T> { items: T[]; nextCursor?: string | null }

// ---- M3 work orders (mirrors AssignmentsService.dto exactly, apps/api/src/assignments/assignments.service.ts) ----
export type AssignmentStatus =
  | 'DRAFT' | 'READY_TO_DELIVER' | 'DELIVERED' | 'IN_PROGRESS' | 'READY_FOR_PICKUP' | 'PICKED_UP' | 'UNDER_REVIEW'
  | 'PARTIALLY_ACCEPTED' | 'ACCEPTED' | 'REWORK_REQUIRED' | 'COMPLETED' | 'CANCELLED';

export interface AssignmentMaterialLine { materialId: string; quantity: number; name?: string | null; unit?: string | null }
export interface AssignmentStatusEvent { from: AssignmentStatus | null; to: AssignmentStatus; actor: string; comment: string | null; changedAt: string }
export interface AssignmentDelivery { id: string; code: string; type: 'DELIVERY_TO_WORKER' | 'PICKUP_FROM_WORKER'; status: 'PENDING' | 'COMPLETED' | 'CANCELLED'; completedAt: string | null }

export interface AssignmentSummary {
  id: string; status: AssignmentStatus; plannedMeters: number; reportedMeters: number; dueAt: string | null;
  worker: { id: string; fullName: string; phone: string }; product: { name: string } | null; color: { name: string; hex: string | null } | null;
}

export interface AssignmentDetail extends AssignmentSummary {
  code: string; kitCount: number; deliveredMeters: number; acceptedMeters: number; defectiveMeters: number;
  calculatedPayment: string | null; notes: string | null; qrCode: string | null;
  variant: { label: string | null } | null;
  materials: AssignmentMaterialLine[]; statusHistory: AssignmentStatusEvent[]; deliveries: AssignmentDelivery[];
}

export interface KitTemplateItem { materialId: string; materialName: string; unit: string; requiredQuantity: number }
export interface KitTemplate { id: string; name: string; variantId: string | null; ribbonMeters: number; baseMeters: number; active: boolean; items: KitTemplateItem[] }

export interface LedgerEntry { id: string; type: 'EARNING' | 'PAYOUT_CASH' | 'BONUS' | 'CORRECTION'; amount: string; comment: string | null; createdAt: string }
export interface WorkerLedger { workerId: string; balance: string; earned: string; paid: string; history: LedgerEntry[] }
