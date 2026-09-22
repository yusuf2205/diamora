// ---- roles (D-004, extended by D-028): SUPER_ADMIN > ADMIN > MANAGER > WORKER ------------------------------------------
export const ROLES = ['SUPER_ADMIN', 'ADMIN', 'MANAGER', 'WORKER'] as const;
export type Role = (typeof ROLES)[number];
/** People who run the business from the staff apps (phone + password login). */
export const STAFF_ROLES = ['SUPER_ADMIN', 'ADMIN', 'MANAGER'] as const;
export type StaffRole = (typeof STAFF_ROLES)[number];
export const isStaffRole = (r: string): r is StaffRole => (STAFF_ROLES as readonly string[]).includes(r);
/** Higher rank = more authority. A user may only manage users of a strictly lower rank (SUPER_ADMIN may manage every role). */
export const ROLE_RANK: Record<Role, number> = { SUPER_ADMIN: 4, ADMIN: 3, MANAGER: 2, WORKER: 1 };

export const WORKER_STATUSES = ['PENDING_APPROVAL', 'ACTIVE', 'PAUSED', 'REJECTED', 'ARCHIVED'] as const;
export type WorkerStatus = (typeof WORKER_STATUSES)[number];

// ---- catalog "Наши работы" (D-029): informational only, NEVER a price ----------------------------------------------------
export const CATALOG_STATUSES = ['DRAFT', 'PUBLISHED', 'HIDDEN'] as const;
export type CatalogStatus = (typeof CATALOG_STATUSES)[number];
export const CATALOG_AVAILABILITY = ['AVAILABLE', 'ON_REQUEST', 'UNAVAILABLE'] as const;
export type CatalogAvailability = (typeof CATALOG_AVAILABILITY)[number];
export const MEDIA_KINDS = ['PHOTO', 'VIDEO'] as const;
export type MediaKind = (typeof MEDIA_KINDS)[number];

export const COLLATERAL_TYPES = ['MONEY', 'ITEM'] as const;
export type CollateralType = (typeof COLLATERAL_TYPES)[number];

export const COLLATERAL_STATUSES = ['PENDING', 'HELD', 'RETURNED'] as const;
export type CollateralStatus = (typeof COLLATERAL_STATUSES)[number];

export const MATERIAL_UNITS = ['METER', 'GRAM', 'PCS', 'SET', 'ROLL', 'PACKAGE'] as const;
export type MaterialUnit = (typeof MATERIAL_UNITS)[number];

/** Fixed material categories (owner request, M2 §5). Seeded once by a migration as `MaterialCategory` rows (`code` column) -
 * kept as a lookup table, not a hard Postgres enum, so the owner can rename the DISPLAY text later without a migration. */
export const MATERIAL_CATEGORY_CODES = ['TAPE', 'BEAD', 'THREAD', 'ACCESSORY', 'OTHER'] as const;
export type MaterialCategoryCode = (typeof MATERIAL_CATEGORY_CODES)[number];

export const STOCK_MOVEMENT_TYPES = [
  'RECEIPT',
  'ISSUE_TO_KIT',
  'ISSUE_TO_WORKER',
  'RETURN_FROM_WORKER',
  'CONSUMPTION',
  'ADJUSTMENT_IN',
  'ADJUSTMENT_OUT',
  'WRITE_OFF',
] as const;
export type StockMovementType = (typeof STOCK_MOVEMENT_TYPES)[number];

export const LEDGER_TYPES = ['EARNING', 'PAYOUT_CASH', 'BONUS', 'CORRECTION'] as const;
export type LedgerType = (typeof LEDGER_TYPES)[number];

export const DELIVERY_TYPES = ['DELIVERY_TO_WORKER', 'PICKUP_FROM_WORKER'] as const;
export type DeliveryType = (typeof DELIVERY_TYPES)[number];
export const DELIVERY_STATUSES = ['PENDING', 'COMPLETED', 'CANCELLED'] as const;
export type DeliveryStatus = (typeof DELIVERY_STATUSES)[number];

export const JOB_REQUEST_STATUSES = ['PENDING', 'APPROVED', 'REJECTED', 'FULFILLED'] as const;
export type JobRequestStatus = (typeof JOB_REQUEST_STATUSES)[number];

export const FILE_BUCKETS = ['collateral', 'assignments', 'products', 'quality', 'documents', 'avatars'] as const;
export type FileBucket = (typeof FILE_BUCKETS)[number];

// ---- phone (Uzbekistan first; Telegram gives E.164 without '+') -----------------------------------------------
export function normalizePhone(input: string): string | null {
  const trimmed = input.trim();
  const hasPlus = trimmed.startsWith('+');
  const digits = trimmed.replace(/\D/g, '');
  if (digits.length === 0) return null;
  if (!hasPlus) {
    if (digits.length === 9) return `+998${digits}`;
    if (digits.length === 12 && digits.startsWith('998')) return `+${digits}`;
    if (digits.length === 10 && digits.startsWith('8')) return `+998${digits.slice(1)}`;
    if (digits.length >= 8 && digits.length <= 15) return `+${digits}`; // e.g. Telegram contact "998901234567"
  }
  if (digits.length < 8 || digits.length > 15) return null;
  if (digits.startsWith('998') && digits.length !== 12) return null;
  return `+${digits}`;
}

// ---- money & metres (D-009) -------------------------------------------------------------------------------------
export const STANDARD_SET_CM = 900; // one 9 m kit
export const KIT_METERS = 9;
/** The price of one 9 m kit is ONE global setting (D-027). The initial value is seeded by a migration; ADMIN changes it later. */
export const INITIAL_PAY_RATE_UZS = 30_000n;
/** Sanity ceiling against a typo (an extra zero): 10 million UZS per 9 m kit. */
export const MAX_PAY_RATE_UZS = 10_000_000n;

export function parseUzs(input: string | number | bigint): bigint {
  if (typeof input === 'bigint') return input;
  if (typeof input === 'number') {
    if (!Number.isSafeInteger(input)) throw new RangeError('UZS amount must be a safe integer');
    return BigInt(input);
  }
  const cleaned = input.replace(/[\s _,]/g, '');
  if (!/^-?\d+$/.test(cleaned)) throw new RangeError(`Invalid UZS amount: "${input}"`);
  return BigInt(cleaned);
}

/** Integer division rounding half away from zero (denominator > 0). */
export function divRoundHalfUp(numerator: bigint, denominator: bigint): bigint {
  if (denominator <= 0n) throw new RangeError('denominator must be positive');
  const negative = numerator < 0n;
  const n = negative ? -numerator : numerator;
  const q = (2n * n + denominator) / (2n * denominator);
  return negative ? -q : q;
}

/**
 * Earning for accepted work (D-024). The price is quoted PER 9 m KIT, never per metre:
 * round_half_up(ratePerKit × acceptedCm / 900). Whole kits are exact multiples of the rate (18 m = 2 × rate);
 * a partly accepted kit is paid pro rata. To pay whole kits only, floor `acceptedCm` to a multiple of 900 here.
 */
export function earningFor(ratePerKit: bigint, acceptedCm: number): bigint {
  if (!Number.isInteger(acceptedCm) || acceptedCm < 0) throw new RangeError('acceptedCm invalid');
  return divRoundHalfUp(ratePerKit * BigInt(acceptedCm), BigInt(STANDARD_SET_CM));
}

export function metersToCm(meters: number | string): number {
  const n = typeof meters === 'string' ? Number(meters) : meters;
  if (!Number.isFinite(n)) throw new RangeError('meters must be finite');
  const cm = Math.round(n * 100);
  if (Math.abs(cm / 100 - n) > 1e-9) throw new RangeError('meters supports at most 2 decimals');
  return cm;
}

export function formatUzs(amount: bigint): string {
  const negative = amount < 0n;
  const s = (negative ? -amount : amount).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  return negative ? `-${s}` : s;
}

// ---- error codes ----------------------------------------------------------------------------------------------------
export const ERROR_CODES = [
  'VALIDATION_FAILED',
  'UNAUTHENTICATED',
  'INVALID_CREDENTIALS',
  'INVALID_CODE',
  'ACCOUNT_DISABLED',
  'SESSION_REVOKED',
  'FORBIDDEN',
  'NOT_FOUND',
  'CONFLICT',
  'INVALID_TRANSITION',
  'INVARIANT_VIOLATION',
  'INSUFFICIENT_STOCK',
  'INSUFFICIENT_BALANCE',
  'IDEMPOTENCY_CONFLICT',
  'RATE_LIMITED',
  'FILE_REJECTED',
  'INTERNAL',
] as const;
export type ErrorCode = (typeof ERROR_CODES)[number];
export interface ApiErrorBody {
  error: { code: ErrorCode; message: string; requestId?: string; details?: unknown };
}

// ---- live location freshness (M2 §17): thresholds live HERE so the API, Flutter and Web all agree ---------------------
/** < 2 min: "Сейчас" / LIVE. */
export const LOCATION_LIVE_SECONDS = 120;
/** 2–10 min: "Обновлено N мин назад" / RECENT. Past this, a position is STALE: never shown as if it were current. */
export const LOCATION_RECENT_SECONDS = 10 * 60;
/** Kept for backward compatibility with the existing `stale` boolean (D-030): STALE starts here, same as RECENT's end. */
export const LOCATION_STALE_SECONDS = LOCATION_RECENT_SECONDS;
export type LocationFreshness = 'LIVE' | 'RECENT' | 'STALE';
export function locationFreshness(ageSeconds: number): LocationFreshness {
  if (ageSeconds < LOCATION_LIVE_SECONDS) return 'LIVE';
  if (ageSeconds < LOCATION_RECENT_SECONDS) return 'RECENT';
  return 'STALE';
}

// ---- QR (D-012): opaque code only -----------------------------------------------------------------------------------
export const QR_PREFIX = 'YQ1.';
const QR_CODE_RE = /^YQ1\.[0-9A-HJKMNP-TV-Z]{12}$/;
/** Extracts the code from scanned text; null when it is not one of ours. */
export function parseQrCode(raw: string): string | null {
  const v = raw.trim().toUpperCase();
  return QR_CODE_RE.test(v) ? v : null;
}
