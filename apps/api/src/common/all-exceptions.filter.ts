import { ArgumentsHost, Catch, ExceptionFilter, HttpException, Inject } from '@nestjs/common';
import { Prisma } from '@yusmus/database';
import { InvalidTransitionError, type ApiErrorBody, type ErrorCode } from '@yusmus/shared';
import type { Response } from 'express';
import { ZodError } from 'zod';
import { AppError } from './errors';
import { AppLogger } from './logger';
import { RequestContext } from './request-context';

const STATUS_TO_CODE: Record<number, ErrorCode> = {
  400: 'VALIDATION_FAILED', 401: 'UNAUTHENTICATED', 403: 'FORBIDDEN', 404: 'NOT_FOUND', 409: 'CONFLICT',
  413: 'FILE_REJECTED', 422: 'VALIDATION_FAILED', 429: 'RATE_LIMITED',
};

interface Mapped { status: number; code: ErrorCode; message: string; details?: unknown; headers?: Record<string, string> }

/** Every error leaves the API in ONE shape: { error: { code, message, requestId, details? } }. */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  constructor(@Inject(AppLogger) private readonly logger: AppLogger) {}

  catch(exception: unknown, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<Response>();
    if (typeof res?.status !== 'function') return; // WebSocket context: nothing to render
    const m = this.map(exception);
    if (m.status >= 500) this.logger.error(exception instanceof Error ? (exception.stack ?? exception.message) : String(exception), undefined, 'ExceptionFilter');
    if (m.headers) for (const [k, v] of Object.entries(m.headers)) res.setHeader(k, v);
    const body: ApiErrorBody = { error: { code: m.code, message: m.message, requestId: RequestContext.get()?.requestId, details: m.details } };
    res.status(m.status).json(body);
  }

  private map(e: unknown): Mapped {
    if (e instanceof AppError) {
      const retry = (e.details as { retryAfterSeconds?: number } | undefined)?.retryAfterSeconds;
      return { status: e.getStatus(), code: e.code, message: e.message, details: e.details, headers: retry ? { 'Retry-After': String(retry) } : undefined };
    }
    if (e instanceof ZodError) {
      return { status: 400, code: 'VALIDATION_FAILED', message: 'Request validation failed', details: e.issues.map((i) => ({ path: i.path.join('.'), message: i.message })) };
    }
    if (e instanceof InvalidTransitionError) return { status: 409, code: 'INVALID_TRANSITION', message: e.message };
    if (e instanceof Prisma.PrismaClientKnownRequestError) {
      if (e.code === 'P2002') return { status: 409, code: 'CONFLICT', message: 'A record with the same unique value already exists' };
      if (e.code === 'P2025') return { status: 404, code: 'NOT_FOUND', message: 'Record not found' };
      if (/append-only|check constraint|restrict_violation/i.test(e.message)) return { status: 409, code: 'INVARIANT_VIOLATION', message: 'Business invariant violated' };
    }
    if (e instanceof HttpException) {
      const status = e.getStatus();
      const r = e.getResponse();
      const message = typeof r === 'string' ? r : ((r as { message?: string | string[] }).message ?? e.message);
      return { status, code: STATUS_TO_CODE[status] ?? (status >= 500 ? 'INTERNAL' : 'VALIDATION_FAILED'), message: Array.isArray(message) ? message.join('; ') : message };
    }
    return { status: 500, code: 'INTERNAL', message: 'Internal server error' };
  }
}
