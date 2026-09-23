import type { Prisma } from '@yusmus/database';
import { createHash, randomBytes } from 'node:crypto';

export type Tx = Prisma.TransactionClient;

/** Cryptographically random, URL-safe bearer token (256 bits) — refresh tokens, Telegram login/handoff tokens. */
export const newOpaqueToken = (): string => randomBytes(32).toString('base64url');
/** Only the hash is ever persisted for a bearer token — the raw value is shown/used once and never stored. */
export const sha256 = (v: string): string => createHash('sha256').update(v).digest('hex');

/** Atomic counter; run inside the same transaction as the insert that uses the number (gap-free). */
export async function nextCode(tx: Tx, key: string, prefix: string, pad: number): Promise<string> {
  const rows = await tx.$queryRaw<{ value: number }[]>`
    INSERT INTO sequences (key, value) VALUES (${key}, 1)
    ON CONFLICT (key) DO UPDATE SET value = sequences.value + 1
    RETURNING value`;
  return `${prefix}${String(rows[0].value).padStart(pad, '0')}`;
}

/** Pessimistic row lock (SELECT ... FOR UPDATE). `table` is a compile-time literal, never user input. */
export async function lockRow(tx: Tx, table: 'worker_collaterals' | 'worker_profiles' | 'work_assignments', id: string): Promise<boolean> {
  const rows = await tx.$queryRawUnsafe<{ id: string }[]>(`SELECT id FROM ${table} WHERE id = $1::uuid FOR UPDATE`, id);
  return rows.length === 1;
}

/** `stock_balances` is keyed by `materialId`, not `id` — a dedicated lock helper (used by StockService.recordMovement). */
export async function lockMaterialBalance(tx: Tx, materialId: string): Promise<boolean> {
  const rows = await tx.$queryRawUnsafe<{ materialId: string }[]>('SELECT "materialId" FROM stock_balances WHERE "materialId" = $1::uuid FOR UPDATE', materialId);
  return rows.length === 1;
}

const B32 = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // Crockford base32 (no I L O U)
/** Opaque QR code: YQ1.<12 chars> (packages/shared parseQrCode validates the same alphabet). */
export function generateQrCode(): string {
  const bytes = randomBytes(12);
  return 'YQ1.' + Array.from(bytes, (b) => B32[b % 32]).join('');
}
