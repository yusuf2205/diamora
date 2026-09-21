import { INestApplication } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import compression from 'compression';
import helmet from 'helmet';
import { AppLogger } from './common/logger';
import './common/serialize';
import { ENV, Env, swaggerEnabled } from './config/env';

/** HTTP configuration shared by production, dev and integration tests (tests exercise the real prefix/hardening). */
export function configureApp(app: NestExpressApplication | INestApplication): void {
  const env = app.get<Env>(ENV);
  const express = app as NestExpressApplication;
  express.set('trust proxy', env.TRUST_PROXY_HOPS); // real client IP behind Caddy
  express.disable('x-powered-by');
  app.useLogger(app.get(AppLogger));
  app.setGlobalPrefix('v1', { exclude: ['health/live', 'health/ready'] });
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' }, contentSecurityPolicy: swaggerEnabled(env) ? false : undefined }));
  app.use(compression());
  const origins = env.CORS_ORIGINS.split(',').map((s) => s.trim()).filter(Boolean);
  app.enableCors({
    origin: origins.length ? origins : false,
    allowedHeaders: ['Authorization', 'Content-Type', 'Idempotency-Key', 'X-Request-Id'],
    exposedHeaders: ['X-Request-Id', 'Idempotent-Replayed', 'Retry-After'],
  });
  app.enableShutdownHooks();
  if (swaggerEnabled(env)) {
    SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, new DocumentBuilder().setTitle('Yusmus API').setVersion('0.1.0').addBearerAuth().build()));
  }
}
