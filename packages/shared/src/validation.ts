import { z } from 'zod';
import {
  CATALOG_AVAILABILITY, CATALOG_STATUSES, COLLATERAL_STATUSES, HANDOFF_PROBLEM_REASONS, MATERIAL_UNITS, MAX_PAY_RATE_UZS, MEDIA_KINDS, STOCK_MOVEMENT_TYPES,
  WORKER_STATUSES, normalizePhone, parseUzs,
} from './basics';
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
export const refreshSchema = z.object({ refreshToken: z.string().min(20).max(512) });

// WORKER auth is Telegram-only (no phone/password/OTP in the app): the app opens a login session (gets a `/start`
// deep link token back), the Telegram bot links it to a telegramUserId and, once confirmed, issues a one-time
// handoff ticket that this same device exchanges for a real session — never a password, never a JWT in a URL.
export const telegramSessionSchema = z.object({ device: deviceSchema });
export const telegramExchangeSchema = z.object({ ticket: z.string().min(16).max(200), device: deviceSchema });
/** Web / PWA: the page that started the Telegram login asks «did she press Start?» — it proves it owns the session by
 * the secret it put into the deep link (never shown to anyone else) and the same installId. */
export const telegramPollSchema = z.object({ sessionToken: z.string().min(16).max(200), device: deviceSchema });

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
  /** typed by whoever creates the account (owner, 2026-09-24: the program never invents passwords) */
  password: passwordSchema,
});
export const updateUserSchema = z
  .object({ fullName: z.string().trim().min(2).max(120), phone: phoneSchema })
  .partial()
  .refine((v) => Object.keys(v).length > 0, { message: 'Nothing to update' });
export const changeRoleSchema = z.object({ role: z.enum(STAFF_ROLE_VALUES) });
/** Anyone with a password changes their OWN: the current one proves it is really them. */
/** «Мой профиль»: anyone may change their OWN first name and surname (stored together as fullName) */
export const updateOwnProfileSchema = z.object({
  fullName: z.string().transform((v) => v.trim().replace(/\s+/g, ' ')).pipe(z.string().min(2).max(120)).optional(),
  /** «О себе» (empty = none) */
  bio: z.string().trim().max(140).nullable().optional(),
  /** @username: letters, digits, _ (5-32); empty = none */
  username: z.string().trim().transform((v) => v.replace(/^@/, '').toLowerCase()).pipe(z.union([z.literal(''), z.string().regex(/^[a-z][a-z0-9_]{4,31}$/)])).nullable().optional(),
});
export const changeOwnPasswordSchema = z.object({ currentPassword: z.string().min(1).max(200), newPassword: passwordSchema });
/** Set someone's password to exactly this (PASSWORD_SET: SUPER_ADMIN always, an ADMIN only if granted). */
export const resetPasswordSchema = z.object({ password: passwordSchema });
/** SUPER_ADMIN only: hide/show this person's position on everybody else's map. */
export const locationVisibilitySchema = z.object({ hidden: z.boolean() });
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
/** «Назначить менеджера» for many workers at once (null = «Без менеджера»). */
export const assignManagerBulkSchema = z.object({ managerId: idSchema.nullable(), workerIds: z.array(idSchema).min(1).max(500) });

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

// ---- materials & stock (M2) — INVENTORY_VIEW / INVENTORY_MANAGE ----------------------------------------------------------
/** Quantities are decimal strings on the wire (mirrors `uzsSchema`'s money handling): up to 3 decimals, never a float. */
export const quantitySchema = z
  .union([z.string().regex(/^\d{1,11}(\.\d{1,3})?$/, 'Quantity must be a positive number with at most 3 decimals'), z.number().positive()])
  .transform((v) => (typeof v === 'number' ? v.toFixed(3) : v));

export const createMaterialSchema = z.object({
  name: z.string().trim().min(2).max(120),
  categoryId: idSchema.nullable().optional(),
  colorId: idSchema.nullable().optional(),
  article: z.string().trim().max(60).optional(),
  unit: z.enum(MATERIAL_UNITS),
  minStock: quantitySchema.optional(),
  /** purchase price per unit (UZS): «Себестоимость», «Стоимость склада», «Прибыль» */
  unitCost: uzsSchema.nullable().optional(),
});
export const updateMaterialSchema = z
  .object({
    name: z.string().trim().min(2).max(120), categoryId: idSchema.nullable(), colorId: idSchema.nullable(),
    article: z.string().trim().max(60).nullable(), unit: z.enum(MATERIAL_UNITS), minStock: quantitySchema, isActive: z.boolean(), unitCost: uzsSchema.nullable(),
  })
  .partial()
  .refine((v) => Object.keys(v).length > 0, { message: 'Nothing to update' });
// ---- owner's analytics: sales and expenses feed «Прибыль» -------------------------------------------------------------------
/** «this phone gets instant notifications»: the Firebase token of a signed-in device */
export const pushTokenSchema = z.object({ token: z.string().min(20).max(4096), platform: z.enum(['android', 'ios', 'web']).default('android') });
/** «Заказать» on diamoraa.uz (no account). `website` is a trap field for bots: people never see or fill it. */
export const clientOrderSchema = z.object({
  name: z.string().trim().min(2).max(80),
  phone: phoneSchema,
  productModelId: idSchema.optional(),
  colorName: z.string().trim().max(60).optional(),
  quantity: z.coerce.number().positive().max(100_000).optional(),
  comment: z.string().trim().max(1000).optional(),
  website: z.string().max(500).optional(),
});
export const CLIENT_ORDER_STATUSES = ['NEW', 'CONFIRMED', 'IN_WORK', 'DONE', 'CANCELLED'] as const;
export const updateClientOrderSchema = z.object({ status: z.enum(CLIENT_ORDER_STATUSES).optional(), staffNote: z.string().trim().max(1000).nullable().optional() });
export const listClientOrdersSchema = z.object({ status: z.enum(CLIENT_ORDER_STATUSES).optional(), limit: z.coerce.number().int().min(1).max(100).default(50) });
export const insightsMonthsSchema = z.object({ months: z.coerce.number().int().min(1).max(24).default(6) });
/** a line of a sale: which product, how many metres, at what price per metre (drives «прибыль по изделиям») */
export const saleLineSchema = z.object({
  productModelId: idSchema,
  quantity: z.coerce.number().positive().max(1_000_000),
  unitPrice: uzsSchema.refine((v) => v > 0n, 'Price must be above zero'),
});
export const createSaleSchema = z.object({
  total: uzsSchema.refine((v) => v > 0n, 'Amount must be above zero'),
  /** optional: what was sold; the total then must equal the sum of the lines */
  items: z.array(saleLineSchema).max(50).optional(),
  customer: z.string().trim().max(120).optional(),
  notes: z.string().trim().max(1000).optional(),
  date: z.coerce.date().optional(),
});
export const EXPENSE_CATEGORIES = ['DELIVERY_FUEL', 'PACKAGING', 'OTHER'] as const;
export const createExpenseSchema = z.object({
  category: z.enum(EXPENSE_CATEGORIES),
  amount: uzsSchema.refine((v) => v > 0n, 'Amount must be above zero'),
  comment: z.string().trim().max(500).optional(),
  date: z.coerce.date().optional(),
});
export const listMaterialsSchema = paginationSchema.extend({
  categoryId: idSchema.optional(),
  isActive: z.coerce.boolean().optional(),
  q: z.string().trim().max(100).optional(),
});

// ---- colors (M3 tech-debt closeout, D-039): a plain lookup shared by Materials, ProductVariant and WorkAssignment ------
export const createColorSchema = z.object({ name: z.string().trim().min(1).max(60), hex: z.string().trim().regex(/^#[0-9a-fA-F]{6}$/, 'hex must be like #RRGGBB').optional() });
export const updateColorSchema = z
  .object({ name: z.string().trim().min(1).max(60), hex: z.string().trim().regex(/^#[0-9a-fA-F]{6}$/, 'hex must be like #RRGGBB').nullable(), isActive: z.boolean() })
  .partial()
  .refine((v) => Object.keys(v).length > 0, { message: 'Nothing to update' });
export const listColorsSchema = z.object({ isActive: z.coerce.boolean().optional() });

export const listStockMovementsSchema = paginationSchema.extend({ materialId: idSchema.optional(), type: z.enum(STOCK_MOVEMENT_TYPES).optional() });
export const stockReceiptSchema = z.object({ materialId: idSchema, quantity: quantitySchema, comment: z.string().trim().max(500).optional() });
export const stockAdjustSchema = z.object({
  materialId: idSchema, direction: z.enum(['IN', 'OUT']), quantity: quantitySchema,
  reason: z.string().trim().min(2).max(500),
});
export const stockWriteOffSchema = z.object({ materialId: idSchema, quantity: quantitySchema, reason: z.string().trim().min(2).max(500) });

// ---- material kit templates — the 9 m recipe (M2 §8-9) --------------------------------------------------------------------
export const kitTemplateItemInput = z.object({ materialId: idSchema, requiredQuantity: quantitySchema });
export const createKitTemplateSchema = z.object({
  name: z.string().trim().min(2).max(120),
  variantId: idSchema.optional(),
  ribbonMeters: z.coerce.number().positive().max(100).default(9),
  items: z.array(kitTemplateItemInput).min(1).max(50),
});
export const updateKitTemplateSchema = z
  .object({ name: z.string().trim().min(2).max(120), variantId: idSchema.nullable(), active: z.boolean(), items: z.array(kitTemplateItemInput).min(1).max(50) })
  .partial()
  .refine((v) => Object.keys(v).length > 0, { message: 'Nothing to update' });
/** Physically assemble N copies of a template from warehouse stock (M2 §8/§11): consumes materials, issues ONE QR for the batch. */
export const assembleKitSchema = z.object({ count: z.coerce.number().int().min(1).max(200).default(1), comment: z.string().trim().max(500).optional() });

// ---- QR (M2 §10-13): opaque code resolve, never personal data in the code itself ------------------------------------------
export const qrCodeParamSchema = z.string().trim().max(40);

// ---- M3: work assignments, delivery, progress, pickup, acceptance, earnings ------------------------------------------
/** 1 = 9 m, 2 = 18 m, 3 = 27 m (the same 9 m kit recipe × count — D-035, never a separate template). */
export const kitCountSchema = z.coerce.number().int().min(1).max(3);
export const metersSchema = z.union([z.string().regex(/^\d{1,8}(\.\d{1,2})?$/, 'Metres must be a positive number with at most 2 decimals'), z.number().nonnegative()])
  .transform((v) => (typeof v === 'number' ? v.toFixed(2) : v));

export const createAssignmentSchema = z.object({
  workerId: idSchema,
  productModelId: idSchema,
  productVariantId: idSchema,
  colorId: idSchema,
  materialKitTemplateId: idSchema,
  kitCount: kitCountSchema,
  dueAt: z.coerce.date().optional(),
  notes: z.string().trim().max(1000).optional(),
  /** prepared from a worker's «Заказать эту работу»: the request becomes FULFILLED in the same transaction */
  jobRequestId: idSchema.optional(),
});

// ---- in-app notifications (bell) ----------------------------------------------------------------------------------------
export const listNotificationsSchema = z.object({
  /** background check: only what arrived after this moment */
  since: z.coerce.date().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});
export const markNotificationsReadSchema = z.object({ ids: z.array(idSchema).max(200).optional(), all: z.boolean().optional() });

// ---- control over any work: cancel (materials back to stock or written off), change deadline / comment ----------------
export const cancelAssignmentSchema = z.object({
  reason: z.string().trim().min(2).max(500),
  /** true = the materials physically came back to the warehouse; false = they are used up / lost (written off) */
  materialsReturned: z.boolean().default(true),
});
export const updateAssignmentSchema = z.object({
  dueAt: z.coerce.date().nullable().optional(),
  notes: z.string().trim().max(1000).nullable().optional(),
}).refine((v) => v.dueAt !== undefined || v.notes !== undefined, 'Nothing to change');

// ---- «Заказать работу»: a worker asks for work from the catalog; staff prepares it or declines --------------------------
export const createJobRequestSchema = z.object({
  productVariantId: idSchema,
  kitCount: kitCountSchema,
  note: z.string().trim().max(500).optional(),
});
export const rejectJobRequestSchema = z.object({ note: z.string().trim().max(500).optional() });
export const listJobRequestsSchema = z.object({ status: z.enum(['PENDING', 'FULFILLED', 'REJECTED', 'CANCELLED']).optional() });

export const reportProgressSchema = z.object({
  reportedMeters: metersSchema,
  comment: z.string().trim().max(500).optional(),
  /** client-generated: an offline retry with the same id is a no-op, never a duplicate row. */
  clientId: z.string().trim().max(80).optional(),
});

export const readyForPickupSchema = z.object({
  readyMeters: metersSchema,
  comment: z.string().trim().max(500).optional(),
  photoFileIds: z.array(idSchema).max(10).optional(),
});

export const completePickupSchema = z.object({ comment: z.string().trim().max(500).optional() });

export const acceptanceSchema = z.object({
  broughtMeters: metersSchema,
  acceptedMeters: metersSchema,
  defectiveMeters: metersSchema.optional(),
  reworkMeters: metersSchema.optional(),
  comment: z.string().trim().max(1000).optional(),
  photoFileIds: z.array(idSchema).max(10).optional(),
});

export const listAssignmentsSchema = paginationSchema.extend({
  workerId: idSchema.optional(),
  status: z.enum([
    'DRAFT', 'READY_TO_DELIVER', 'DELIVERED', 'IN_PROGRESS', 'READY_FOR_PICKUP', 'PICKED_UP',
    'UNDER_REVIEW', 'PARTIALLY_ACCEPTED', 'ACCEPTED', 'REWORK_REQUIRED', 'COMPLETED', 'CANCELLED',
  ]).optional(),
});

export const completeDeliverySchema = z.object({ comment: z.string().trim().max(500).optional() });

// ---- worker invitation: staff adds a worker, she opens the Telegram link and is active at once ------------------------
export const createWorkerInviteSchema = z.object({
  fullName: z.string().trim().min(2).max(120),
  phone: phoneSchema,
  managerId: idSchema.nullable().optional(),
});

// ---- two-sided QR handoff (Phase 5) ---------------------------------------------------------------------------------
export const handoffScanSchema = z.object({ code: z.string().trim().min(1).max(64) });
export const handoffConfirmSchema = z.object({
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  accuracyM: z.number().nonnegative().max(100000).optional(),
});
export const handoffProblemSchema = z.object({
  reason: z.enum(HANDOFF_PROBLEM_REASONS),
  comment: z.string().trim().max(500).optional(),
});

// ---- money: cash payout (M3 §15) ---------------------------------------------------------------------------------------
export const cashPayoutSchema = z.object({
  amount: uzsSchema,
  comment: z.string().trim().max(500).optional(),
  /** ADMIN paying more than the current balance — allowed, but flagged in the ledger and audit. */
  forced: z.boolean().optional(),
});

// ---- chat (everyone with everyone: direct, groups, one company-wide chat) -------------------------------------------------
export const CHAT_KINDS = ['DIRECT', 'GROUP', 'COMPANY', 'CHANNEL'] as const;
export type ChatKind = (typeof CHAT_KINDS)[number];
export const CHAT_MESSAGE_KINDS = ['TEXT', 'IMAGE', 'VIDEO', 'VOICE', 'AUDIO', 'FILE'] as const;
export type ChatMessageKind = (typeof CHAT_MESSAGE_KINDS)[number];
/** the largest file a chat message may carry (photos, videos, voice, documents) */
export const CHAT_MAX_FILE_BYTES = 50 * 1024 * 1024;
/** videos may be larger (sent in parts: Cloudflare takes at most 100 MB per request) */
export const CHAT_MAX_VIDEO_BYTES = 150 * 1024 * 1024;
/** one part of a resumable upload */
export const CHAT_CHUNK_BYTES = 5 * 1024 * 1024;
export const chatDirectSchema = z.object({ userId: z.string().uuid() });
export const chatGroupSchema = z.object({
  title: z.string().trim().min(1).max(80),
  memberIds: z.array(z.string().uuid()).min(1).max(500),
});
export const chatGroupUpdateSchema = z.object({
  title: z.string().trim().min(1).max(80).optional(),
  description: z.string().trim().max(500).nullable().optional(),
  addIds: z.array(z.string().uuid()).max(500).optional(),
  removeIds: z.array(z.string().uuid()).max(500).optional(),
  /** make / unmake group or channel admins */
  adminIds: z.array(z.string().uuid()).max(100).optional(),
  unadminIds: z.array(z.string().uuid()).max(100).optional(),
  onlyAdminsWrite: z.boolean().optional(),
});
export const CHAT_AUDIENCES = ['ALL', 'STAFF', 'WORKERS', 'CUSTOM'] as const;
export const chatChannelSchema = z.object({
  title: z.string().trim().min(1).max(80),
  description: z.string().trim().max(500).optional(),
  audience: z.enum(CHAT_AUDIENCES),
  memberIds: z.array(z.string().uuid()).max(500).default([]),
});
export const chatMediaQuerySchema = z.object({
  kind: z.enum(['media', 'files', 'voice', 'links']),
  before: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(60),
});
export const chatTextSchema = z.object({ text: z.string().trim().min(1).max(4000), clientId: z.string().max(64).optional(), replyToId: z.string().uuid().optional() });
export const chatEditSchema = z.object({ text: z.string().trim().min(1).max(4000) });
/** the reactions offered (a fixed, safe set) */
export const CHAT_REACTIONS = ['👍', '❤️', '😂', '😮', '😢', '🙏', '👏', '🔥'] as const;
export const chatReactSchema = z.object({ emoji: z.enum(CHAT_REACTIONS) });
export const chatForwardSchema = z.object({ roomIds: z.array(z.string().uuid()).min(1).max(20) });
export const chatPinSchema = z.object({ messageId: z.string().uuid().nullable() });
export const chatMemberPrefsSchema = z.object({ pinned: z.boolean().optional(), muted: z.boolean().optional() });
export const chatSearchSchema = z.object({ q: z.string().trim().min(2).max(80) });
export const chatProtectSchema = z.object({ on: z.boolean() });
export const chatFileFieldsSchema = z.object({
  kind: z.enum(['IMAGE', 'VIDEO', 'VOICE', 'AUDIO', 'FILE']).optional(),
  text: z.string().trim().max(4000).optional(),
  durationMs: z.coerce.number().int().min(0).max(6 * 3600_000).optional(),
  clientId: z.string().max(64).optional(),
  replyToId: z.string().uuid().optional(),
  width: z.coerce.number().int().min(1).max(20_000).optional(),
  height: z.coerce.number().int().min(1).max(20_000).optional(),
  waveform: z.string().regex(/^(\d{1,2},){0,63}\d{1,2}$/).optional(),
});
/** start (or resume, same clientId) a file sent in parts */
export const chatUploadStartSchema = z.object({
  name: z.string().trim().min(1).max(200),
  size: z.coerce.number().int().min(1).max(150 * 1024 * 1024),
  kind: z.enum(['IMAGE', 'VIDEO', 'VOICE', 'AUDIO', 'FILE']),
  clientId: z.string().min(8).max(64),
  text: z.string().trim().max(4000).optional(),
  durationMs: z.coerce.number().int().min(0).max(6 * 3600_000).optional(),
  replyToId: z.string().uuid().optional(),
  width: z.coerce.number().int().min(1).max(20_000).optional(),
  height: z.coerce.number().int().min(1).max(20_000).optional(),
  waveform: z.string().regex(/^(\d{1,2},){0,63}\d{1,2}$/).optional(),
});
export const chatMessagesQuerySchema = z.object({
  before: z.string().uuid().optional(),
  after: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(40),
});
export const chatContactsQuerySchema = z.object({ q: z.string().trim().max(80).optional() });
