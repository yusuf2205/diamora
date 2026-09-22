import { z } from 'zod';
import { CATALOG_AVAILABILITY, CATALOG_STATUSES, COLLATERAL_STATUSES, MAX_PAY_RATE_UZS, MEDIA_KINDS, WORKER_STATUSES, normalizePhone, parseUzs } from './basics';
import { PERMISSIONS } from './permissions';

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

// ---- users, roles, permissions, manager assignment (D-028) ----------------------------------------------------------------------
/** Accounts that sign in with phone + password. WORKERs exist only through the Telegram registration (their identity is Telegram). */
export const STAFF_ROLE_VALUES = ['SUPER_ADMIN', 'ADMIN', 'MANAGER'] as const;
export const createUserSchema = z.object({
  phone: phoneSchema,
  fullName: z.string().trim().min(2).max(120),
  role: z.enum(STAFF_ROLE_VALUES),
  /** omitted = the server generates a strong one-time password and returns it once */
  password: passwordSchema.optional(),
});
export const updateUserSchema = z
  .object({ fullName: z.string().trim().min(2).max(120), phone: phoneSchema })
  .partial()
  .refine((v) => Object.keys(v).length > 0, { message: 'Nothing to update' });
export const changeRoleSchema = z.object({ role: z.enum(STAFF_ROLE_VALUES) });
export const setUserStatusSchema = z.object({ status: z.enum(['ACTIVE', 'SUSPENDED']), reason: z.string().trim().max(500).optional() });
export const listUsersSchema = paginationSchema.extend({
  role: z.enum(['SUPER_ADMIN', 'ADMIN', 'MANAGER', 'WORKER']).optional(),
  status: z.enum(['ACTIVE', 'SUSPENDED']).optional(),
  q: z.string().trim().max(100).optional(),
});
/** Full replacement of one user's overrides: `grant` adds to the role defaults, `revoke` takes defaults away. */
export const setPermissionsSchema = z.object({
  grant: z.array(z.enum(PERMISSIONS)).max(64).default([]),
  revoke: z.array(z.enum(PERMISSIONS)).max(64).default([]),
});
export const assignManagerSchema = z.object({ managerId: idSchema.nullable() });

// ---- catalog "Наши работы" (D-029) - informational only, never a price -----------------------------------------------------
export const createCatalogItemSchema = z.object({
  name: z.string().trim().min(2).max(120),
  description: z.string().trim().max(2000).optional(),
});
export const updateCatalogItemSchema = z
  .object({
    name: z.string().trim().min(2).max(120), description: z.string().trim().max(2000).nullable(),
    availability: z.enum(CATALOG_AVAILABILITY), isNew: z.boolean(),
  })
  .partial()
  .refine((v) => Object.keys(v).length > 0, { message: 'Nothing to update' });
export const listCatalogSchema = paginationSchema.extend({ status: z.enum(CATALOG_STATUSES).optional() });
export const reorderSchema = z.object({ ids: z.array(idSchema).min(1).max(500) });
export const createVariantSchema = z.object({ colorId: idSchema, label: z.string().trim().max(80).optional() });
export const updateVariantSchema = z.object({ label: z.string().trim().max(80).nullable(), active: z.boolean() }).partial()
  .refine((v) => Object.keys(v).length > 0, { message: 'Nothing to update' });
export const addMediaSchema = z.object({ kind: z.enum(MEDIA_KINDS).default('PHOTO'), variantId: idSchema.optional(), caption: z.string().trim().max(200).optional() });

// ---- live location (D-030) --------------------------------------------------------------------------------------------------
export const reportLocationSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  accuracy: z.number().min(0).max(100_000).optional(),
  heading: z.number().min(0).max(360).optional(),
  speed: z.number().min(0).max(120).optional(),
  /** device clock, ISO; the server also stamps its own receivedAt */
  recordedAt: z.coerce.date(),
  isBackground: z.boolean().default(false),
});

export const companyContactSchema = z.object({
  phone: phoneSchema.nullable(),
  telegramUsername: z.string().trim().regex(/^@?[A-Za-z0-9_]{5,32}$/, 'Invalid Telegram username').nullable(),
});

/** ADMIN sets the ONE global price of a 9 m kit (UZS, whole number, 1 … 10 000 000). */
export const changePayRateSchema = z.object({
  ratePerKit: uzsSchema.refine((v) => v >= 1n && v <= MAX_PAY_RATE_UZS, { message: `Rate must be between 1 and ${MAX_PAY_RATE_UZS} UZS` }),
  note: z.string().trim().max(500).optional(),
});
