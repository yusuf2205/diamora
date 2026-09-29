import { Controller, Delete, Get, Global, HttpCode, Module, Param, ParseUUIDPipe, Patch, Post, Req, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { fileRejected } from '../common/errors';
import { JwtModule } from '@nestjs/jwt';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { adminLoginSchema, changeOwnPasswordSchema, refreshSchema, telegramExchangeSchema, telegramPollSchema, telegramSessionSchema, updateOwnProfileSchema, workerCodeRequestSchema } from '@diamoraa/shared';
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

  @Public() @Throttle({ default: { limit: 20, ttl: 60_000 } }) @Post('telegram/session') @HttpCode(200)
  @ApiOperation({ summary: 'WORKER: start a Telegram-only login — returns a one-time /start deep link, never a phone/password/OTP flow' }) @ApiZodBody(telegramSessionSchema)
  telegramSession(@ZodBody(telegramSessionSchema) b: z.output<typeof telegramSessionSchema>) { return this.auth.telegramSession(b.device); }

  @Public() @Throttle({ default: { limit: 20, ttl: 60_000 } }) @Post('telegram/exchange') @HttpCode(200)
  @ApiOperation({ summary: 'WORKER: exchange the bot handoff ticket for a real session (or a not-ready-yet status)' }) @ApiZodBody(telegramExchangeSchema)
  telegramExchange(@ZodBody(telegramExchangeSchema) b: z.output<typeof telegramExchangeSchema>, @Req() r: Request) { return this.auth.telegramExchange(b, meta(r)); }

  @Public() @Throttle({ default: { limit: 120, ttl: 60_000 } }) @Post('telegram/poll') @HttpCode(200)
  @ApiOperation({ summary: 'WORKER (web/PWA): the tab that started the Telegram login asks whether she pressed Start' }) @ApiZodBody(telegramPollSchema)
  telegramPoll(@ZodBody(telegramPollSchema) b: z.output<typeof telegramPollSchema>, @Req() r: Request) { return this.auth.telegramPoll(b, meta(r)); }

  @Public() @Throttle({ default: { limit: 60, ttl: 60_000 } }) @Post('refresh') @HttpCode(200) @ApiZodBody(refreshSchema)
  refresh(@ZodBody(refreshSchema) b: z.output<typeof refreshSchema>, @Req() r: Request) { return this.auth.refresh(b.refreshToken, meta(r)); }

  @Authenticated() @ApiBearerAuth() @Post('logout') @HttpCode(204)
  async logout(@CurrentUser() u: AuthUser) { await this.auth.logout(u); }

  @Authenticated() @ApiBearerAuth() @Post('logout-all') @HttpCode(200)
  logoutAll(@CurrentUser() u: AuthUser) { return this.auth.logoutAll(u); }

  @Authenticated() @ApiBearerAuth() @Post('change-password') @HttpCode(200) @ApiZodBody(changeOwnPasswordSchema)
  changePassword(@CurrentUser() u: AuthUser, @ZodBody(changeOwnPasswordSchema) b: z.output<typeof changeOwnPasswordSchema>) {
    return this.auth.changeOwnPassword(u, b.currentPassword, b.newPassword);
  }

  @Authenticated() @ApiBearerAuth() @Get('me')
  me(@CurrentUser() u: AuthUser) { return this.auth.me(u); }

  @Authenticated() @ApiBearerAuth() @Patch('me') @ApiZodBody(updateOwnProfileSchema)
  @ApiOperation({ summary: 'Change your OWN first name and surname (every role)' })
  updateMe(@CurrentUser() u: AuthUser, @ZodBody(updateOwnProfileSchema) b: z.output<typeof updateOwnProfileSchema>) { return this.auth.updateOwnProfile(u, b); }

  @Authenticated() @ApiBearerAuth() @Post('me/avatar') @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 15 * 1024 * 1024 } }))
  avatar(@CurrentUser() u: AuthUser, @UploadedFile() file?: Express.Multer.File) {
    if (!file) throw fileRejected('Attach the photo as multipart field "file"');
    return this.auth.setAvatar(u, file.buffer);
  }

  @Authenticated() @ApiBearerAuth() @Delete('me/avatar') @HttpCode(200)
  removeAvatar(@CurrentUser() u: AuthUser) { return this.auth.setAvatar(u, null); }

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
