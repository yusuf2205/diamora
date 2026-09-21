/**
 * Realtime event contracts (docs/REALTIME.md). Events are hints published AFTER the database COMMIT;
 * payloads are small ids/summaries — clients refetch details from the API.
 */
export interface EventMap {
  'worker.created': { workerId: string; code: string; fullName: string; status: string };
  'worker.approved': { workerId: string };
  'worker.rejected': { workerId: string };
  'worker.location.updated': { workerId: string; latitude: number; longitude: number; receivedAt: string };
  'collateral.created': { collateralId: string; workerId: string; type: string; status: string };
  'collateral.updated': { collateralId: string; workerId: string; type: string; status: string };
  'job_request.created': { requestId: string; workerId: string; kitCount: number };
  'job_request.decided': { requestId: string; workerId: string; status: string };
  'assignment.created': { assignmentId: string; workerId: string };
  'assignment.status_changed': { assignmentId: string; workerId: string; from: string; to: string };
  'work.progress_updated': { assignmentId: string; workerId: string; reportedMeters: number; percent: number };
  'work.ready_for_pickup': { assignmentId: string; workerId: string; meters: number };
  'delivery.created': { deliveryId: string; workerId: string; type: string; assignmentId: string | null };
  'delivery.completed': { deliveryId: string; workerId: string; type: string; assignmentId: string | null };
  'quality.completed': { assignmentId: string; workerId: string; result: string; acceptedMeters: number };
  /** The global price of a 9 m kit changed: everybody's screens must refresh (D-027). */
  'pay_rate.changed': { ratePerKit: string; previousRatePerKit: string | null; changedAt: string };
  'earning.created': { workerId: string; assignmentId: string | null; amount: string };
  'cash_payment.created': { workerId: string; paymentId: string; amount: string };
  'worker.balance_updated': { workerId: string; balance: string; earned: string; paid: string };
  'stock.updated': { materialId: string; quantity: string; low: boolean };
  'sale.created': { saleId: string };
  'profit.updated': { period: string };
}
export type EventType = keyof EventMap;

/** Who receives the event. `worker` = only the worker named in `data.workerId`; `allWorkers` = every connected worker. */
export const EVENT_AUDIENCE: Record<EventType, { admin: boolean; worker: boolean; allWorkers?: boolean }> = {
  'worker.created': { admin: true, worker: false },
  'worker.approved': { admin: true, worker: true },
  'worker.rejected': { admin: true, worker: true },
  'worker.location.updated': { admin: true, worker: false },
  'collateral.created': { admin: true, worker: false },
  'collateral.updated': { admin: true, worker: true },
  'job_request.created': { admin: true, worker: false },
  'job_request.decided': { admin: false, worker: true },
  'assignment.created': { admin: true, worker: true },
  'assignment.status_changed': { admin: true, worker: true },
  'work.progress_updated': { admin: true, worker: false },
  'work.ready_for_pickup': { admin: true, worker: false },
  'delivery.created': { admin: true, worker: true },
  'delivery.completed': { admin: true, worker: true },
  'quality.completed': { admin: true, worker: true },
  'pay_rate.changed': { admin: true, worker: false, allWorkers: true },
  'earning.created': { admin: true, worker: true },
  'cash_payment.created': { admin: true, worker: true },
  'worker.balance_updated': { admin: true, worker: true },
  'stock.updated': { admin: true, worker: false },
  'sale.created': { admin: true, worker: false },
  'profit.updated': { admin: true, worker: false },
};

export interface RealtimeEnvelope<T extends EventType = EventType> {
  id: string;
  type: T;
  occurredAt: string;
  data: EventMap[T];
}

export const ADMIN_ROOM = 'admin';
/** Every connected WORKER socket joins this room (broadcasts such as `pay_rate.changed`). */
export const WORKERS_ROOM = 'workers';
export const workerRoom = (workerId: string) => `worker:${workerId}`;
export const EVENTS_CHANNEL = 'yusmus:events';
