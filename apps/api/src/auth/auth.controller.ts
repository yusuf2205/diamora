import { Controller, Delete, Get, Global, HttpCode, Module, Param, ParseUUIDPipe, Post, Req } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { adminLoginSchema, refreshSchema, workerCodeRequestSchema, workerLoginSchema } from '@yusmus/shared';
import type { Request } from 'express';
import { z } from 'zod';
import { ApiZodBody, Authenticated, CurrentUser, Public } from '../common/decorators';
import type { AuthUser } from '../common/request-context';
import { ZodBody } from '../common/zod.pipe';
import { ENV, Env } from '../config/env';
import { JwtAuthGuard, PasswordService, RolesGuard, SessionAuthService } from './auth-core';
import { AuthService, ClientMeta } from './auth.service';

const meta = (r: Request): ClientMeta => ({ ip: r.ip, userAgent: r.headers['user-agent'] });

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public() @Throttle({ default: { limit: 20, ttl: 60_000 } }) @Post('identify') @HttpCode(200)
  @ApiOperation({ summary: 'Unified login step 1: phone -> which method (PASSWORD/CODE) to show next. The client never picks a role.' }) @ApiZodBody(workerCodeRequestSchema)
  identify(@ZodBody(workerCodeRequestSchema) b: z.output<typeof workerCodeRequestSchema>, @Req() r: Request) { return this.auth.identify(b.phone, meta(r)); }

  @Public() @Throttle({ default: { limit: 20, ttl: 60_000 } }) @Post('admin/login') @HttpCode(200)
  @ApiOperation({ summary: 'ADMIN: phone + password' }) @ApiZodBody(adminLoginSchema)
  adminLogin(@ZodBody(adminLoginSchema) b: z.output<typeof adminLoginSchema>, @Req() r: Request) { return this.auth.adminLogin(b, meta(r)); }

  @Public() @Throttle({ default: { limit: 10, ttl: 60_000 } }) @Post('worker/code') @HttpCode(200)
  @ApiOperation({ summary: 'WORKER: ask the Telegram bot to send a one-time code' }) @ApiZodBody(workerCodeRequestSchema)
  workerCode(@ZodBody(workerCodeRequestSchema) b: z.output<typeof workerCodeRequestSchema>, @Req() r: Request) { return this.auth.requestWorkerCode(b.phone, meta(r)); }

  @Public() @Throttle({ default: { limit: 20, ttl: 60_000 } }) @Post('worker/login') @HttpCode(200)
  @ApiOperation({ summary: 'WORKER: phone + code from Telegram' }) @ApiZodBody(workerLoginSchema)
  workerLogin(@ZodBody(workerLoginSchema) b: z.output<typeof workerLoginSchema>, @Req() r: Request) { return this.auth.workerLogin(b, meta(r)); }

  @Public() @Throttle({ default: { limit: 60, ttl: 60_000 } }) @Post('refresh') @HttpCode(200) @ApiZodBody(refreshSchema)
  refresh(@ZodBody(refreshSchema) b: z.output<typeof refreshSchema>, @Req() r: Request) { return this.auth.refresh(b.refreshToken, meta(r)); }

  @Authenticated() @ApiBearerAuth() @Post('logout') @HttpCode(204)
  async logout(@CurrentUser() u: AuthUser) { await this.auth.logout(u); }

  @Authenticated() @ApiBearerAuth() @Post('logout-all') @HttpCode(200)
  logoutAll(@CurrentUser() u: AuthUser) { return this.auth.logoutAll(u); }

  @Authenticated() @ApiBearerAuth() @Get('me')
  me(@CurrentUser() u: AuthUser) { return this.auth.me(u); }

  @Authenticated() @ApiBearerAuth() @Get('sessions')
  sessions(@CurrentUser() u: AuthUser) { return this.auth.listSessions(u); }

  @Authenticated() @ApiBearerAuth() @Delete('sessions/:id') @HttpCode(204)
  async revoke(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { await this.auth.revokeOwn(u, id); }
}

@Global()
@Module({
  imports: [
    JwtModule.registerAsync({
      inject: [ENV],
      useFactory: (env: Env) => ({ secret: env.JWT_ACCESS_SECRET, signOptions: { algorithm: 'HS256', expiresIn: env.ACCESS_TOKEN_TTL_SECONDS } }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, PasswordService, SessionAuthService, JwtAuthGuard, RolesGuard],
  exports: [AuthService, PasswordService, SessionAuthService, JwtAuthGuard, RolesGuard, JwtModule],
})
export class AuthModule {}
