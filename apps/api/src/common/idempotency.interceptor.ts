import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { HTTP_CODE_METADATA } from '@nestjs/common/constants';
import { Prisma } from '@yusmus/database';
import type { Request, Response } from 'express';
import { createHash } from 'node:crypto';
import { Observable, catchError, from, of, switchMap, throwError } from 'rxjs';
import { PrismaService } from '../prisma/prisma.module';
import { AppError, validationFailed } from './errors';
import { jsonSafe } from './serialize';

const MUTATING = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

/**
 * Safe retries for offline clients: with an `Idempotency-Key` header the operation runs at most once and the stored
 * result is replayed. Multipart uploads are excluded (photos are de-duplicated by content hash instead).
 */
@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  constructor(private readonly prisma: PrismaService) {}

  intercept(ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    const http = ctx.switchToHttp();
    const req = http.getRequest<Request>();
    const res = http.getResponse<Response>();
    const key = req.header?.('idempotency-key');
    if (!key || !MUTATING.has(req.method) || !req.user) return next.handle();
    if (req.is('multipart/form-data')) return next.handle();
    if (key.length < 8 || key.length > 100) throw validationFailed('Idempotency-Key must be 8-100 characters');

    const userId = req.user.id;
    const hash = createHash('sha256').update(`${req.method}\n${req.originalUrl}\n${JSON.stringify(req.body ?? {})}`).digest('hex');
    const status = (Reflect.getMetadata(HTTP_CODE_METADATA, ctx.getHandler()) as number | undefined) ?? (req.method === 'POST' ? 201 : 200);

    return from(this.claim(userId, key, req, hash)).pipe(
      switchMap((existing) => {
        if (existing) {
          res.setHeader('Idempotent-Replayed', 'true');
          return of(existing.body);
        }
        return next.handle().pipe(
          switchMap((body) => from(this.complete(userId, key, status, body)).pipe(switchMap(() => of(body)))),
          catchError((err) => from(this.release(userId, key)).pipe(switchMap(() => throwError(() => err)))),
        );
      }),
    );
  }

  private async claim(userId: string, key: string, req: Request, requestHash: string): Promise<{ body: unknown } | null> {
    try {
      await this.prisma.idempotencyKey.create({ data: { userId, key, method: req.method, path: req.path, requestHash } });
      return null;
    } catch (e) {
      if (!(e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002')) throw e;
    }
    const row = await this.prisma.idempotencyKey.findUnique({ where: { userId_key: { userId, key } } });
    if (!row) return this.claim(userId, key, req, requestHash);
    if (row.requestHash !== requestHash) throw new AppError('IDEMPOTENCY_CONFLICT', 'This Idempotency-Key was already used for a different request', 422);
    if (row.statusCode === null) throw new AppError('CONFLICT', 'The original request is still being processed, retry shortly', 409);
    return { body: row.responseBody };
  }
  private async complete(userId: string, key: string, statusCode: number, body: unknown) {
    await this.prisma.idempotencyKey.update({ where: { userId_key: { userId, key } }, data: { statusCode, responseBody: body === undefined ? Prisma.JsonNull : jsonSafe(body) } });
  }
  private async release(userId: string, key: string) {
    await this.prisma.idempotencyKey.deleteMany({ where: { userId, key, statusCode: null } });
  }
}
