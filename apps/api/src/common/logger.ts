import { Inject, Injectable, LoggerService } from '@nestjs/common';
import pino, { Logger } from 'pino';
import { ENV, Env } from '../config/env';
import { RequestContext } from './request-context';

/** Structured JSON logs, one line per event (ready for Loki/promtail later). */
@Injectable()
export class AppLogger implements LoggerService {
  private readonly logger: Logger;

  constructor(@Inject(ENV) env: Env) {
    this.logger = pino({
      level: env.LOG_LEVEL,
      base: { service: process.env.SERVICE_NAME ?? 'api' },
      timestamp: pino.stdTimeFunctions.isoTime,
      redact: ['req.headers.authorization', '*.password', '*.refreshToken', '*.accessToken', '*.code'],
      mixin: () => {
        const c = RequestContext.get();
        return c ? { requestId: c.requestId, userId: c.user?.id } : {};
      },
    });
  }
  log(m: unknown, context?: string) { this.logger.info({ context }, this.fmt(m)); }
  error(m: unknown, trace?: string, context?: string) { this.logger.error({ context, trace }, this.fmt(m)); }
  warn(m: unknown, context?: string) { this.logger.warn({ context }, this.fmt(m)); }
  debug(m: unknown, context?: string) { this.logger.debug({ context }, this.fmt(m)); }
  verbose(m: unknown, context?: string) { this.logger.trace({ context }, this.fmt(m)); }
  event(name: string, fields: Record<string, unknown>, level: 'info' | 'warn' | 'error' = 'info') {
    this.logger[level]({ event: name, ...fields });
  }
  private fmt(m: unknown): string { return typeof m === 'string' ? m : JSON.stringify(m); }
}
