import { Controller, Get, Injectable, Module, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { companyContactSchema } from '@yusmus/shared';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, Authenticated, CurrentUser, Perm } from '../common/decorators';
import type { AuthUser } from '../common/request-context';
import { ZodBody } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { PrismaService } from '../prisma/prisma.module';

/**
 * Company phone + Telegram shown in the WORKER app ("Позвонить" / "Написать в Telegram", D-029). Never hard-coded in Flutter:
 * the app reads this endpoint and refreshes live on `company_contact.changed`. Single row (id = 1), seeded empty by the migration.
 */
@Injectable()
export class CompanyContactService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly events: EventBus) {}

  async get() {
    return this.dto(await this.prisma.companyContactSettings.findUniqueOrThrow({ where: { id: 1 } }));
  }

  async update(actor: AuthUser, input: z.output<typeof companyContactSchema>) {
    const telegramUsername = input.telegramUsername ? input.telegramUsername.replace(/^@/, '') : null;
    const telegramUrl = telegramUsername ? `https://t.me/${telegramUsername}` : null;
    const row = await this.prisma.$transaction(async (tx) => {
      const before = await tx.companyContactSettings.findUniqueOrThrow({ where: { id: 1 } });
      const after = await tx.companyContactSettings.update({ where: { id: 1 }, data: { phone: input.phone, telegramUsername, telegramUrl, updatedById: actor.id } });
      await this.audit.record({
        action: 'settings.company_contact', entity: 'CompanyContactSettings', entityId: '1',
        before: { phone: before.phone, telegramUsername: before.telegramUsername }, after: { phone: after.phone, telegramUsername: after.telegramUsername },
      }, tx);
      return after;
    });
    await this.events.publish('company_contact.changed', { phone: row.phone, telegramUsername: row.telegramUsername, telegramUrl: row.telegramUrl });
    return this.dto(row);
  }

  private dto(r: { phone: string | null; telegramUsername: string | null; telegramUrl: string | null; updatedAt: Date }) {
    return { phone: r.phone, telegramUsername: r.telegramUsername, telegramUrl: r.telegramUrl, updatedAt: r.updatedAt.toISOString() };
  }
}

@ApiTags('settings')
@ApiBearerAuth()
@Controller('settings/company-contact')
export class CompanyContactController {
  constructor(private readonly settings: CompanyContactService) {}

  /** Any authenticated role, including WORKER: this is what the "Позвонить" / Telegram buttons read. */
  @Authenticated() @Get()
  get() { return this.settings.get(); }

  @Perm('SETTINGS_MANAGE') @Put() @ApiZodBody(companyContactSchema)
  update(@CurrentUser() u: AuthUser, @ZodBody(companyContactSchema) b: z.output<typeof companyContactSchema>) { return this.settings.update(u, b); }
}

@Module({ controllers: [CompanyContactController], providers: [CompanyContactService], exports: [CompanyContactService] })
export class CompanyContactModule {}
