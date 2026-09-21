import type { Role } from './basics';

/** Who may trigger a transition. SYSTEM = automatic effect of another domain event. */
export type Actor = Role | 'SYSTEM';

export interface Transition<S extends string> {
  to: S;
  actors: readonly Actor[];
  label: string;
}
export type Machine<S extends string> = Readonly<Record<S, readonly Transition<S>[]>>;

export class InvalidTransitionError extends Error {
  readonly code = 'INVALID_TRANSITION' as const;
  constructor(readonly machine: string, readonly from: string, readonly to: string, readonly actor: Actor) {
    super(`${machine}: ${actor} may not perform ${from} -> ${to}`);
    this.name = 'InvalidTransitionError';
  }
}

/** ADMIN may perform every edge except SYSTEM-only ones; WORKER only edges that list WORKER. */
function allowed(edge: Transition<string>, actor: Actor): boolean {
  if (edge.actors.includes(actor)) return true;
  const systemOnly = edge.actors.length === 1 && edge.actors[0] === 'SYSTEM';
  return actor === 'ADMIN' && !systemOnly;
}

export function canTransition<S extends string>(m: Machine<S>, from: S, to: S, actor: Actor): boolean {
  const edge = m[from]?.find((t) => t.to === to);
  return edge !== undefined && allowed(edge, actor);
}

export function assertTransition<S extends string>(name: string, m: Machine<S>, from: S, to: S, actor: Actor): void {
  if (!canTransition(m, from, to, actor)) throw new InvalidTransitionError(name, from, to, actor);
}

export function allowedTransitions<S extends string>(m: Machine<S>, from: S, actor: Actor): S[] {
  return (m[from] ?? []).filter((t) => allowed(t, actor)).map((t) => t.to);
}

export function isTerminal<S extends string>(m: Machine<S>, s: S): boolean {
  return (m[s] ?? []).length === 0;
}

// ---- WorkAssignment (brief §23) ------------------------------------------------------------------------------------
export const ASSIGNMENT_STATUSES = [
  'DRAFT',
  'READY_TO_DELIVER',
  'DELIVERED',
  'IN_PROGRESS',
  'READY_FOR_PICKUP',
  'PICKED_UP',
  'UNDER_REVIEW',
  'PARTIALLY_ACCEPTED',
  'ACCEPTED',
  'REWORK_REQUIRED',
  'COMPLETED',
  'CANCELLED',
] as const;
export type AssignmentStatus = (typeof ASSIGNMENT_STATUSES)[number];

export const ASSIGNMENT_MACHINE: Machine<AssignmentStatus> = {
  DRAFT: [
    { to: 'READY_TO_DELIVER', actors: ['ADMIN'], label: 'Kit issued from stock, QR generated' },
    { to: 'CANCELLED', actors: ['ADMIN'], label: 'Cancel draft' },
  ],
  READY_TO_DELIVER: [
    { to: 'DELIVERED', actors: ['ADMIN', 'SYSTEM'], label: 'Delivery completed' },
    { to: 'CANCELLED', actors: ['ADMIN'], label: 'Cancel, materials return to stock' },
  ],
  DELIVERED: [{ to: 'IN_PROGRESS', actors: ['WORKER', 'SYSTEM'], label: 'First progress' }],
  IN_PROGRESS: [{ to: 'READY_FOR_PICKUP', actors: ['WORKER'], label: 'Work is ready' }],
  READY_FOR_PICKUP: [
    { to: 'IN_PROGRESS', actors: ['WORKER'], label: 'Reopen' },
    { to: 'PICKED_UP', actors: ['ADMIN', 'SYSTEM'], label: 'Pickup completed' },
  ],
  PICKED_UP: [{ to: 'UNDER_REVIEW', actors: ['ADMIN', 'SYSTEM'], label: 'Start review' }],
  UNDER_REVIEW: [
    { to: 'ACCEPTED', actors: ['ADMIN'], label: 'Fully accepted' },
    { to: 'PARTIALLY_ACCEPTED', actors: ['ADMIN'], label: 'Partially accepted' },
    { to: 'REWORK_REQUIRED', actors: ['ADMIN'], label: 'Needs rework' },
  ],
  PARTIALLY_ACCEPTED: [
    { to: 'COMPLETED', actors: ['ADMIN', 'SYSTEM'], label: 'Close' },
    { to: 'REWORK_REQUIRED', actors: ['ADMIN'], label: 'Remainder to rework' },
  ],
  ACCEPTED: [{ to: 'COMPLETED', actors: ['ADMIN', 'SYSTEM'], label: 'Close' }],
  REWORK_REQUIRED: [{ to: 'IN_PROGRESS', actors: ['ADMIN', 'WORKER'], label: 'Rework started' }],
  COMPLETED: [],
  CANCELLED: [],
};

// ---- Worker profile -----------------------------------------------------------------------------------------------
export const WORKER_MACHINE: Machine<import('./basics').WorkerStatus> = {
  PENDING_APPROVAL: [
    { to: 'ACTIVE', actors: ['ADMIN'], label: 'Approve' },
    { to: 'REJECTED', actors: ['ADMIN'], label: 'Reject' },
  ],
  ACTIVE: [
    { to: 'PAUSED', actors: ['ADMIN'], label: 'Pause' },
    { to: 'ARCHIVED', actors: ['ADMIN'], label: 'Archive' },
  ],
  PAUSED: [
    { to: 'ACTIVE', actors: ['ADMIN'], label: 'Resume' },
    { to: 'ARCHIVED', actors: ['ADMIN'], label: 'Archive' },
  ],
  REJECTED: [],
  ARCHIVED: [],
};

// ---- Collateral -----------------------------------------------------------------------------------------------------
export const COLLATERAL_MACHINE: Machine<import('./basics').CollateralStatus> = {
  PENDING: [{ to: 'HELD', actors: ['ADMIN'], label: 'Physically received' }],
  HELD: [{ to: 'RETURNED', actors: ['ADMIN'], label: 'Returned to the worker' }],
  RETURNED: [],
};

// ---- Delivery & job request ---------------------------------------------------------------------------------------
export const DELIVERY_MACHINE: Machine<import('./basics').DeliveryStatus> = {
  PENDING: [
    { to: 'COMPLETED', actors: ['ADMIN'], label: 'Delivered / picked up' },
    { to: 'CANCELLED', actors: ['ADMIN'], label: 'Cancel' },
  ],
  COMPLETED: [],
  CANCELLED: [],
};

export const JOB_REQUEST_MACHINE: Machine<import('./basics').JobRequestStatus> = {
  PENDING: [
    { to: 'APPROVED', actors: ['ADMIN'], label: 'Approve' },
    { to: 'REJECTED', actors: ['ADMIN'], label: 'Reject' },
  ],
  APPROVED: [{ to: 'FULFILLED', actors: ['ADMIN', 'SYSTEM'], label: 'Assignment created' }],
  REJECTED: [],
  FULFILLED: [],
};
