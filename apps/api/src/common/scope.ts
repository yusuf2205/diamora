import type { Prisma } from '@yusmus/database';
import { scopeFor, type Permission, type WorkerCategory } from '@yusmus/shared';
import { forbidden, notFound } from './errors';
import type { AuthUser } from './request-context';

/**
 * SERVER-SIDE data scoping (D-028). Which workers a user may see is derived from their EFFECTIVE permissions and their own id -
 * never from anything the client sends (a `managerId` in a request is ignored/validated, never trusted).
 *   ALL      -> every worker
 *   ASSIGNED -> only workers whose assignedManagerId is the user's id
 * The realtime rooms (packages/shared roomsForUser) use the same `scopeFor`, so REST and WebSocket can never disagree.
 */
export const can = (user: AuthUser, p: Permission): boolean => user.permissions.includes(p);

export interface WorkerScope { scope: 'all' | 'assigned'; where: Prisma.WorkerProfileWhereInput }

/** WorkerProfile filter for a category; 403 when the user may not see this kind of data at all. */
export function workerScope(user: AuthUser, cat: WorkerCategory): WorkerScope {
  const s = scopeFor(user.permissions, cat);
  if (s === 'none') throw forbidden();
  return { scope: s, where: s === 'all' ? {} : { assignedManagerId: user.id } };
}

/** Is this worker inside the user's scope for the category? */
export function inWorkerScope(user: AuthUser, cat: WorkerCategory, worker: { assignedManagerId: string | null }): boolean {
  const s = scopeFor(user.permissions, cat);
  return s === 'all' || (s === 'assigned' && worker.assignedManagerId === user.id);
}

/** 404 (not 403) for a worker outside the scope: the existence of other managers' workers is not revealed. */
export function assertWorkerInScope(user: AuthUser, cat: WorkerCategory, worker: { assignedManagerId: string | null }, what = 'Worker'): void {
  if (!inWorkerScope(user, cat, worker)) throw notFound(what);
}
