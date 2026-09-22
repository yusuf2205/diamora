import { ExecutionContext, SetMetadata, applyDecorators, createParamDecorator } from '@nestjs/common';
import { ApiBody } from '@nestjs/swagger';
import type { Permission, Role } from '@yusmus/shared';
import { z } from 'zod';
import type { AuthUser } from './request-context';

export const IS_PUBLIC = 'yusmus:isPublic';
export const IS_AUTHENTICATED = 'yusmus:isAuthenticated';
export const ROLES_KEY = 'yusmus:roles';
export const PERMISSIONS_KEY = 'yusmus:permissions';

/** No authentication (login, health, signed file URLs). */
export const Public = () => SetMetadata(IS_PUBLIC, true);
/** Any authenticated user. Routes are DENY-by-default: a route needs @Public, @Authenticated or @Roles. */
export const Authenticated = () => SetMetadata(IS_AUTHENTICATED, true);
/** Only these roles. */
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);

/** Any of these permissions (effective permissions, resolved server-side). Combine with @Roles to also restrict the role. */
export const Perm = (...permissions: Permission[]) => SetMetadata(PERMISSIONS_KEY, permissions);

export const CurrentUser = createParamDecorator((_d: unknown, ctx: ExecutionContext): AuthUser => ctx.switchToHttp().getRequest().user as AuthUser);

/** Swagger body from the zod schema (single source of truth). */
export function ApiZodBody(schema: z.ZodType) {
  return applyDecorators(ApiBody({ schema: z.toJSONSchema(schema, { io: 'input', unrepresentable: 'any' }) as Record<string, unknown> }));
}
