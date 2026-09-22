import { HttpException } from '@nestjs/common';
import type { ErrorCode } from '@yusmus/shared';

export class AppError extends HttpException {
  constructor(readonly code: ErrorCode, message: string, status: number, readonly details?: unknown) {
    super({ code, message, details }, status);
  }
}

export const unauthenticated = (m = 'Authentication required') => new AppError('UNAUTHENTICATED', m, 401);
export const invalidCredentials = () => new AppError('INVALID_CREDENTIALS', 'Invalid phone or password', 401);
export const invalidCode = () => new AppError('INVALID_CODE', 'Invalid or expired code', 401);
export const sessionRevoked = () => new AppError('SESSION_REVOKED', 'Session is no longer valid', 401);
export const forbidden = (m = 'You do not have permission to do this') => new AppError('FORBIDDEN', m, 403);
export const notFound = (what: string) => new AppError('NOT_FOUND', `${what} not found`, 404);
export const conflict = (m: string, details?: unknown) => new AppError('CONFLICT', m, 409, details);
export const invariant = (m: string, details?: unknown) => new AppError('INVARIANT_VIOLATION', m, 409, details);
export const validationFailed = (m: string, details?: unknown) => new AppError('VALIDATION_FAILED', m, 400, details);
export const rateLimited = (retryAfterSeconds: number) =>
  new AppError('RATE_LIMITED', 'Too many attempts, try again later', 429, { retryAfterSeconds });
export const fileRejected = (m: string) => new AppError('FILE_REJECTED', m, 422);
export const insufficientStock = (m = 'Not enough stock', details?: unknown) => new AppError('INSUFFICIENT_STOCK', m, 409, details);
