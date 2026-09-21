import { z } from 'zod';
import { COLLATERAL_STATUSES, MAX_PAY_RATE_UZS, WORKER_STATUSES, normalizePhone, parseUzs } from './basics';

export const idSchema = z.uuid();

export const phoneSchema = z
  .string()
  .trim()
  .refine((v) => normalizePhone(v) !== null, { message: 'Invalid phone number' })
  .transform((v) => normalizePhone(v) as string);

export const passwordSchema = z.string().min(8, 'At least 8 characters').max(128);

/** whole UZS as digit string or safe integer -> bigint */
export const uzsSchema = z
  .union([z.string().regex(/^\d{1,15}$/, 'Amount must be a whole number'), z.number().int().nonnegative().max(Number.MAX_SAFE_INTEGER)])
  .transform((v) => parseUzs(v));

export const paginationSchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  cursor: idSchema.optional(),
  updatedSince: z.coerce.date().optional(),
});

export const deviceSchema = z.object({
  installId: z.string().min(8).max(100),
  platform: z.enum(['ANDROID', 'IOS', 'WEB']),
  name: z.string().max(100).optional(),
  appVersion: z.string().max(50).optional(),
});

export const adminLoginSchema = z.object({ phone: phoneSchema, password: z.string().min(1).max(200), device: deviceSchema });
export const workerCodeRequestSchema = z.object({ phone: phoneSchema });
export const workerLoginSchema = z.object({
  phone: phoneSchema,
  code: z.string().regex(/^\d{6}$/, 'Code is 6 digits'),
  device: deviceSchema,
});
export const refreshSchema = z.object({ refreshToken: z.string().min(20).max(512) });

export const listWorkersSchema = paginationSchema.extend({
  status: z.enum(WORKER_STATUSES).optional(),
  q: z.string().trim().max(100).optional(),
});
export const updateWorkerSchema = z
  .object({
    phone: phoneSchema,
    secondaryPhone: phoneSchema.nullable(),
    notes: z.string().trim().max(2000).nullable(),
    status: z.enum(['ACTIVE', 'PAUSED', 'ARCHIVED']),
  })
  .partial()
  .refine((v) => Object.keys(v).length > 0, { message: 'Nothing to update' });
export const approveWorkerSchema = z.object({
  /** ADMIN physically received the declared collateral while approving */
  collateralReceived: z.boolean().default(false),
  note: z.string().trim().max(1000).optional(),
});
export const rejectWorkerSchema = z.object({ reason: z.string().trim().min(3).max(1000) });

export const listCollateralSchema = paginationSchema.extend({
  workerId: idSchema.optional(),
  status: z.enum(COLLATERAL_STATUSES).optional(),
});
export const receiveCollateralSchema = z.object({
  estimatedValue: uzsSchema.optional(),
  storageLocation: z.string().trim().max(200).optional(),
  note: z.string().trim().max(1000).optional(),
});
export const returnCollateralSchema = z.object({
  note: z.string().trim().min(2).max(1000),
  workerConfirmed: z.literal(true),
});

/** ADMIN sets the ONE global price of a 9 m kit (UZS, whole number, 1 … 10 000 000). */
export const changePayRateSchema = z.object({
  ratePerKit: uzsSchema.refine((v) => v >= 1n && v <= MAX_PAY_RATE_UZS, { message: `Rate must be between 1 and ${MAX_PAY_RATE_UZS} UZS` }),
  note: z.string().trim().max(500).optional(),
});
