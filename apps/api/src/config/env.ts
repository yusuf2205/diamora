import { Global, Module } from '@nestjs/common';
import { z } from 'zod';

const bool = (def: boolean) =>
  z
    .enum(['true', 'false', '1', '0'])
    .default(def ? 'true' : 'false')
    .transform((v) => v === 'true' || v === '1');

export const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    HOST: z.string().default('0.0.0.0'),
    PORT: z.coerce.number().int().min(1).max(65535).default(3000),
    LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),

    DATABASE_URL: z.string().min(1),
    /** Redis = realtime bus between processes. Unset -> in-process bus (tests / single process). */
    REDIS_URL: z.string().optional(),

    JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET must be at least 32 chars'),
    FILE_SIGNING_SECRET: z.string().min(32, 'FILE_SIGNING_SECRET must be at least 32 chars'),
    ACCESS_TOKEN_TTL_SECONDS: z.coerce.number().int().min(60).default(900),
    REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().min(1).default(30),
    REFRESH_REUSE_GRACE_SECONDS: z.coerce.number().int().min(0).default(30),
    LOGIN_MAX_FAILURES: z.coerce.number().int().min(1).default(5),
    LOGIN_LOCK_MINUTES: z.coerce.number().int().min(1).default(15),
    LOGIN_CODE_TTL_MINUTES: z.coerce.number().int().min(1).default(5),
    LOGIN_CODE_MAX_ATTEMPTS: z.coerce.number().int().min(1).default(5),

    STORAGE_DRIVER: z.enum(['s3', 'memory']).default('s3'),
    S3_ENDPOINT: z.string().optional(),
    S3_REGION: z.string().default('us-east-1'),
    S3_ACCESS_KEY: z.string().optional(),
    S3_SECRET_KEY: z.string().optional(),
    S3_FORCE_PATH_STYLE: bool(true),
    S3_BUCKET_PREFIX: z.string().default(''),
    S3_AUTO_CREATE_BUCKETS: bool(false),

    PUBLIC_API_URL: z.string().default('http://localhost:3000'),
    SIGNED_URL_TTL_SECONDS: z.coerce.number().int().min(30).default(600),
    CORS_ORIGINS: z.string().default(''),
    TRUST_PROXY_HOPS: z.coerce.number().int().min(0).default(1),
    MAX_UPLOAD_BYTES: z.coerce.number().int().min(1024).default(15 * 1024 * 1024),
    RATE_LIMIT_ENABLED: bool(true),
    RATE_LIMIT_PER_MINUTE: z.coerce.number().int().min(1).default(300),
    SWAGGER_ENABLED: z.enum(['true', 'false', '1', '0']).optional(),

    /** worker process (Telegram bot) */
    TELEGRAM_BOT_TOKEN: z.string().optional(),
    WORKER_HEALTH_PORT: z.coerce.number().int().default(3100),
  })
  .superRefine((v, ctx) => {
    if (v.STORAGE_DRIVER === 's3') {
      for (const k of ['S3_ENDPOINT', 'S3_ACCESS_KEY', 'S3_SECRET_KEY'] as const) {
        if (!v[k]) ctx.addIssue({ code: 'custom', path: [k], message: `${k} is required when STORAGE_DRIVER=s3` });
      }
    }
    if (v.NODE_ENV === 'production' && v.STORAGE_DRIVER === 'memory') {
      ctx.addIssue({ code: 'custom', path: ['STORAGE_DRIVER'], message: 'memory storage is not allowed in production' });
    }
  });

export type Env = z.infer<typeof envSchema>;

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const parsed = envSchema.safeParse(source);
  if (!parsed.success) {
    throw new Error(`Invalid environment configuration:\n${parsed.error.issues.map((i) => `  - ${i.path.join('.')}: ${i.message}`).join('\n')}`);
  }
  return parsed.data;
}

export const ENV = Symbol('ENV');

export function swaggerEnabled(env: Env): boolean {
  if (env.SWAGGER_ENABLED !== undefined) return env.SWAGGER_ENABLED === 'true' || env.SWAGGER_ENABLED === '1';
  return env.NODE_ENV !== 'production';
}

@Global()
@Module({ providers: [{ provide: ENV, useFactory: () => loadEnv() }], exports: [ENV] })
export class EnvModule {}
