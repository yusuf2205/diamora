import type { Role } from './basics';
import { WORKER_CATEGORIES, scopeFor, type Permission, type WorkerCategory } from './permissions';

/**
 * Realtime event contracts (docs/REALTIME.md). Events are hints published AFTER the database COMMIT; payloads are small
 * ids/summaries - clients refetch details from the API. WHO receives an event is decided by the SERVER from `EVENT_ROUTES`:
 * a client never receives data it may not see and "hides it in the UI".
 * Events about a worker carry `managerId` (the worker's assigned MANAGER, or null) so that manager-scoped rooms can be addressed.
 */
type WithManager = { managerId?: string | null };

export interface EventMap {
  // users, roles, presence
  'user.created': { userId: string; role: Role; fullName: string };
  'user.updated': { userId: string };
  'user.role_changed': { userId: string; from: Role; to: Role };
  'user.permission_changed': { userId: string };
  'user.presence_changed': { userId: string; role: Role; online: boolean; lastSeenAt: string | null } & WithManager;
  'user.location.updated': { userId: string; role: Role; latitude: number; longitude: number; recordedAt: string } & WithManager & { workerId?: string };
  // workers
  'worker.created': { workerId: string; code: string; fullName: string; status: string } & WithManager;
  'worker.approved': { workerId: string } & WithManager;
  'worker.rejected': { workerId: string } & WithManager;
  'worker.manager_changed': { workerId: string; managerId: string | null; previousManagerId: string | null };
  'worker.location.updated': { workerId: string; latitude: number; longitude: number; receivedAt: string } & WithManager;
  'collateral.created': { collateralId: string; workerId: string; type: string; status: string } & WithManager;
  'collateral.updated': { collateralId: string; workerId: string; type: string; status: string } & WithManager;
  // catalog + company settings
  'catalog.item.created': { itemId: string };
  'catalog.item.updated': { itemId: string };
  'catalog.item.published': { itemId: string };
  'catalog.item.hidden': { itemId: string };
  'catalog.item.deleted': { itemId: string };
  'catalog.order.changed': Record<string, never>;
  'company_contact.changed': { phone: string | null; telegramUsername: string | null; telegramUrl: string | null };
  // work (M3+)
  'job_request.created': { requestId: string; workerId: string; kitCount: number } & WithManager;
  'job_request.decided': { requestId: string; workerId: string; status: string } & WithManager;
  'assignment.created': { assignmentId: string; workerId: string } & WithManager;
  'assignment.updated': { assignmentId: string; workerId: string } & WithManager;
  'assignment.status_changed': { assignmentId: string; workerId: string; from: string; to: string } & WithManager;
  'work.progress_updated': { assignmentId: string; workerId: string; reportedMeters: number; percent: number } & WithManager;
  'work.ready_for_pickup': { assignmentId: string; workerId: string; meters: number } & WithManager;
  'delivery.created': { deliveryId: string; workerId: string; type: string; assignmentId: string | null } & WithManager;
  'delivery.completed': { deliveryId: string; workerId: string; type: string; assignmentId: string | null } & WithManager;
  'quality.completed': { assignmentId: string; workerId: string; result: string; acceptedMeters: number } & WithManager;
  // money
  /** The global price of a 9 m kit changed: everybody's screens must refresh (D-027). */
  'pay_rate.changed': { ratePerKit: string; previousRatePerKit: string | null; changedAt: string };
  'earning.created': { workerId: string; assignmentId: string | null; amount: string } & WithManager;
  'cash_payment.created': { workerId: string; paymentId: string; amount: string } & WithManager;
  'worker.balance_updated': { workerId: string; balance: string; earned: string; paid: string } & WithManager;
  'stock.updated': { materialId: string; quantity: string; low: boolean };
  'sale.created': { saleId: string };
  'profit.updated': { period: string };
}
export type EventType = keyof EventMap;

/**
 * Routing table. Rooms are computed from it (see `roomsForEvent`):
 *   perms      -> everyone holding one of these permissions          (room perm:<P>)
 *   cat        -> worker-scoped data: users who see ALL workers of that category, plus the worker's own MANAGER if that manager may see it
 *   worker     -> the worker named in data.workerId
 *   allWorkers -> every connected worker;  staff -> every connected staff user;  user -> the user named in data.userId
 */
export interface EventRoute {
  perms?: readonly Permission[];
  cat?: WorkerCategory;
  worker?: boolean;
  allWorkers?: boolean;
  staff?: boolean;
  user?: boolean;
}

const w = (cat: WorkerCategory, worker = true): EventRoute => ({ cat, worker });

export const EVENT_ROUTES: Record<EventType, EventRoute> = {
  'user.created': { perms: ['USER_VIEW_ALL'] },
  'user.updated': { perms: ['USER_VIEW_ALL'], user: true },
  'user.role_changed': { perms: ['USER_VIEW_ALL'], user: true },
  'user.permission_changed': { perms: ['USER_VIEW_ALL'], user: true },
  'user.presence_changed': { perms: ['USER_VIEW_ALL'], cat: 'WORKER' },
  'user.location.updated': { perms: ['LIVE_LOCATION_VIEW_ALL'], cat: 'LOCATION', user: true },
  'worker.created': w('WORKER', false),
  'worker.approved': w('WORKER'),
  'worker.rejected': w('WORKER'),
  'worker.manager_changed': { cat: 'WORKER' },
  'worker.location.updated': { cat: 'LOCATION' },
  'collateral.created': w('COLLATERAL', false),
  'collateral.updated': w('COLLATERAL'),
  'catalog.item.created': { perms: ['CATALOG_VIEW'] },
  'catalog.item.updated': { perms: ['CATALOG_VIEW'] },
  'catalog.item.published': { perms: ['CATALOG_VIEW'], allWorkers: true },
  'catalog.item.hidden': { perms: ['CATALOG_VIEW'], allWorkers: true },
  'catalog.item.deleted': { perms: ['CATALOG_VIEW'], allWorkers: true },
  'catalog.order.changed': { perms: ['CATALOG_VIEW'], allWorkers: true },
  'company_contact.changed': { staff: true, allWorkers: true },
  'job_request.created': w('ASSIGNMENT', false),
  'job_request.decided': w('ASSIGNMENT'),
  'assignment.created': w('ASSIGNMENT'),
  'assignment.updated': w('ASSIGNMENT'),
  'assignment.status_changed': w('ASSIGNMENT'),
  'work.progress_updated': w('ASSIGNMENT', false),
  'work.ready_for_pickup': w('ASSIGNMENT', false),
  'delivery.created': w('ASSIGNMENT'),
  'delivery.completed': w('ASSIGNMENT'),
  'quality.completed': w('ASSIGNMENT'),
  'pay_rate.changed': { staff: true, allWorkers: true },
  'earning.created': w('FINANCE'),
  'cash_payment.created': w('FINANCE'),
  'worker.balance_updated': w('FINANCE'),
  'stock.updated': { perms: ['INVENTORY_VIEW'] },
  'sale.created': { perms: ['PROFIT_VIEW'] },
  'profit.updated': { perms: ['PROFIT_VIEW'] },
};

export interface RealtimeEnvelope<T extends EventType = EventType> {
  id: string;
  type: T;
  occurredAt: string;
  data: EventMap[T];
}

// ---- rooms ----------------------------------------------------------------------------------------------------------------
export const STAFF_ROOM = 'staff';
/** Every connected WORKER socket joins this room (broadcasts such as `pay_rate.changed`). */
export const WORKERS_ROOM = 'workers';
export const workerRoom = (workerId: string) => `worker:${workerId}`;
export const userRoom = (userId: string) => `user:${userId}`;
export const permRoom = (p: Permission) => `perm:${p}`;
export const catAllRoom = (c: WorkerCategory) => `cat:${c}:all`;
export const catManagerRoom = (c: WorkerCategory, managerId: string) => `cat:${c}:mgr:${managerId}`;
export const EVENTS_CHANNEL = 'yusmus:events';

export interface SocketPrincipal { id: string; role: Role; workerId: string | null; permissions: readonly Permission[] }

/** Rooms one authenticated socket joins - computed from its user's EFFECTIVE permissions at connect time. */
export function roomsForUser(u: SocketPrincipal): string[] {
  const rooms = [userRoom(u.id)];
  if (u.role === 'WORKER') {
    rooms.push(WORKERS_ROOM);
    if (u.workerId) rooms.push(workerRoom(u.workerId));
    return rooms;
  }
  rooms.push(STAFF_ROOM);
  for (const p of u.permissions) rooms.push(permRoom(p));
  for (const cat of Object.keys(WORKER_CATEGORIES) as WorkerCategory[]) {
    const s = scopeFor(u.permissions, cat);
    if (s === 'all') rooms.push(catAllRoom(cat));
    else if (s === 'assigned') rooms.push(catManagerRoom(cat, u.id));
  }
  return rooms;
}

/** Rooms an event must be emitted to. */
export function roomsForEvent(type: EventType, data: unknown): string[] {
  const route = EVENT_ROUTES[type];
  if (!route) return [];
  const d = (data ?? {}) as { workerId?: string; userId?: string; managerId?: string | null; previousManagerId?: string | null };
  const rooms: string[] = [];
  for (const p of route.perms ?? []) rooms.push(permRoom(p));
  if (route.cat) {
    rooms.push(catAllRoom(route.cat));
    if (d.managerId) rooms.push(catManagerRoom(route.cat, d.managerId));
    if (d.previousManagerId) rooms.push(catManagerRoom(route.cat, d.previousManagerId)); // the old manager's list must drop the worker
  }
  if (route.worker && d.workerId) rooms.push(workerRoom(d.workerId));
  if (route.allWorkers) rooms.push(WORKERS_ROOM);
  if (route.staff) rooms.push(STAFF_ROOM);
  if (route.user && d.userId) rooms.push(userRoom(d.userId));
  return [...new Set(rooms)];
}
