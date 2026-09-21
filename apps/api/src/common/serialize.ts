import type { Prisma } from '@yusmus/database';

// JSON has no bigint: money travels as a decimal string. Safety net for raw rows (audit snapshots, idempotency replays).
if (!(BigInt.prototype as unknown as { toJSON?: unknown }).toJSON) {
  (BigInt.prototype as unknown as { toJSON: () => string }).toJSON = function toJSON(this: bigint) {
    return this.toString();
  };
}

export const money = (v: bigint | null | undefined): string | null => (v === null || v === undefined ? null : v.toString());
export const num = (v: Prisma.Decimal | number | null | undefined): number | null =>
  v === null || v === undefined ? null : typeof v === 'number' ? v : v.toNumber();

const REDACTED = new Set(['passwordHash', 'password', 'code', 'codeHash', 'refreshTokenHash', 'previousRefreshTokenHash', 'refreshToken', 'accessToken', 'token']);

/** Deep clone to plain JSON (bigint -> string, Decimal -> string, Date -> ISO) with secrets removed. */
export function jsonSafe<T>(value: T): Prisma.InputJsonValue {
  return JSON.parse(JSON.stringify(value, (k, v) => (REDACTED.has(k) ? undefined : v))) as Prisma.InputJsonValue;
}
