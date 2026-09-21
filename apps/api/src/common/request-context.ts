import { AsyncLocalStorage } from 'node:async_hooks';
import type { Role } from '@yusmus/shared';

/** The authenticated principal. Loaded from the DB session on every request — never trusted from the client. */
export interface AuthUser {
  id: string;
  role: Role;
  fullName: string;
  sessionId: string;
  /** WorkerProfile id when role = WORKER */
  workerId: string | null;
}

export interface RequestStore {
  requestId: string;
  ip?: string;
  userAgent?: string;
  user?: AuthUser;
}

const storage = new AsyncLocalStorage<RequestStore>();

export const RequestContext = {
  run<T>(store: RequestStore, fn: () => T): T {
    return storage.run(store, fn);
  },
  get(): RequestStore | undefined {
    return storage.getStore();
  },
  setUser(user: AuthUser): void {
    const s = storage.getStore();
    if (s) s.user = user;
  },
};

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthUser;
      requestId?: string;
    }
  }
}
