import { Inject, Injectable } from '@nestjs/common';
import { statfs } from 'node:fs/promises';
import { dirname } from 'node:path';
import { readFile } from 'node:fs/promises';
import { ENV, Env } from '../config/env';
import { PrismaService } from '../prisma/prisma.module';
import { materialUsage, RUNOUT_WARN_DAYS } from '../stock/forecast';

const TASHKENT_MS = 5 * 3600_000;
const dayStart = (d: Date) => new Date(Math.floor((d.getTime() + TASHKENT_MS) / 86_400_000) * 86_400_000 - TASHKENT_MS);
const sum = (n: bigint | number) => `${Number(n).toLocaleString('ru-RU').replace(/ /g, ' ')} сум`;
const m = (v: number) => `${Math.round(v * 10) / 10} м`;

/** The owner's menu in the bot (the ⌘ button next to the message field): quick read-only summaries. */
export const ADMIN_MENU = [
  ['📊 Итоги дня', '🛒 Заказы'],
  ['📦 Склад', '💰 К выплате'],
  ['🧵 Работы', '🖥 Сервер'],
] as const;
export const adminKeyboard = { keyboard: ADMIN_MENU.map((row) => row.map((text) => ({ text }))), resize_keyboard: true, is_persistent: true };

const OPEN = ['READY_TO_DELIVER', 'DELIVERED', 'IN_PROGRESS', 'READY_FOR_PICKUP', 'PICKED_UP', 'UNDER_REVIEW', 'REWORK_REQUIRED'] as const;
const STATUS_RU: Record<string, string> = {
  READY_TO_DELIVER: 'ждут доставку', DELIVERED: 'доставлены', IN_PROGRESS: 'в работе', READY_FOR_PICKUP: 'готовы к забору',
  PICKED_UP: 'забраны', UNDER_REVIEW: 'на проверке', REWORK_REQUIRED: 'на доработке',
};

/**
 * Read-only answers for the admins who linked their chat (Профиль → Оповещения в Telegram). Nothing here changes data;
 * a chat that is not a linked, active admin gets nothing from it (the bot then treats it as before).
 */
@Injectable()
export class AdminBot {
  constructor(private readonly prisma: PrismaService, @Inject(ENV) private readonly env: Env) {}

  async isAdminChat(chatId: bigint) {
    const u = await this.prisma.user.findFirst({ where: { alertChatId: chatId, status: 'ACTIVE', role: { in: ['SUPER_ADMIN', 'ADMIN'] } }, select: { id: true } });
    return !!u;
  }

  /** null = not a menu button (the caller shows the menu). */
  async answer(text: string, now = new Date()): Promise<string | null> {
    switch (text.trim()) {
      case '📊 Итоги дня': return this.today(now);
      case '🛒 Заказы': return this.orders();
      case '📦 Склад': return this.stock(now);
      case '💰 К выплате': return this.payouts();
      case '🧵 Работы': return this.works(now);
      case '🖥 Сервер': return this.server();
      default: return null;
    }
  }

  menuText() {
    return 'Меню Diamoraa — нажмите кнопку внизу:\n📊 итоги дня · 🛒 новые заказы · 📦 склад · 💰 к выплате · 🧵 работы · 🖥 сервер';
  }

  private async today(now: Date) {
    const from = dayStart(now);
    const [issued, inspected, earned, paid, orders] = await Promise.all([
      this.prisma.workAssignment.aggregate({ where: { createdAt: { gte: from } }, _count: { _all: true }, _sum: { plannedMeters: true } }),
      this.prisma.qualityInspection.aggregate({ where: { inspectedAt: { gte: from } }, _sum: { acceptedMeters: true, defectiveMeters: true } }),
      this.prisma.workerLedgerTransaction.aggregate({ where: { createdAt: { gte: from }, type: 'EARNING' }, _sum: { amount: true } }),
      this.prisma.workerLedgerTransaction.aggregate({ where: { createdAt: { gte: from }, type: 'PAYOUT_CASH' }, _sum: { amount: true } }),
      this.prisma.clientOrder.count({ where: { createdAt: { gte: from } } }),
    ]);
    return [
      '📊 Итоги дня',
      `Выдано работ: ${issued._count._all} (${m(Number(issued._sum.plannedMeters ?? 0))})`,
      `Принято: ${m(Number(inspected._sum.acceptedMeters ?? 0))}${Number(inspected._sum.defectiveMeters ?? 0) ? `, брак ${m(Number(inspected._sum.defectiveMeters))}` : ''}`,
      `Начислено мастерицам: ${sum(earned._sum.amount ?? 0n)}`,
      `Выплачено: ${sum(-(paid._sum.amount ?? 0n))}`,
      `Заказов с сайта: ${orders}`,
    ].join('\n');
  }

  private async orders() {
    const rows = await this.prisma.clientOrder.findMany({ where: { status: 'NEW' }, orderBy: { createdAt: 'desc' }, take: 5, include: { productModel: { select: { name: true } } } });
    const total = await this.prisma.clientOrder.count({ where: { status: 'NEW' } });
    if (!total) return '🛒 Новых заказов нет.';
    return [
      `🛒 Новые заказы: ${total}`,
      ...rows.map((o) => `• ${o.code} ${o.name}, ${o.phone}${o.productModel ? ` — ${o.productModel.name}` : ''}${o.colorName ? `, ${o.colorName}` : ''}${o.quantity ? `, ${Number(o.quantity)} м` : ''}`),
      total > rows.length ? `…и ещё ${total - rows.length}. Все — в панели «Заказы клиентов».` : 'Подробнее — в панели «Заказы клиентов».',
    ].join('\n');
  }

  private async stock(now: Date) {
    const mats = await this.prisma.material.findMany({ where: { isActive: true, deletedAt: null }, include: { balance: true }, orderBy: { name: 'asc' } });
    const qty = new Map(mats.map((x) => [x.id, Number(x.balance?.quantity ?? 0)]));
    const usage = await materialUsage(this.prisma, qty, now);
    const lines = mats.flatMap((x) => {
      const left = qty.get(x.id) ?? 0;
      const u = usage.get(x.id);
      const low = left < Number(x.minStock);
      const soon = u?.daysLeft !== null && u?.daysLeft !== undefined && u.daysLeft <= RUNOUT_WARN_DAYS;
      if (left <= 0 && (low || soon)) return [`🔴 ${x.name}: закончился`];
      if (low || soon) return [`🟠 ${x.name}: осталось ${left}${u?.daysLeft != null ? `, хватит ≈ на ${u.daysLeft} дн.` : ''}`];
      return [];
    });
    return lines.length ? ['📦 Склад — пора закупить:', ...lines].join('\n') : '📦 Склад: всего хватает (ничего не заканчивается в ближайшую неделю).';
  }

  private async payouts() {
    const owed = await this.prisma.workerProfile.findMany({ where: { balance: { gt: 0 }, deletedAt: null }, orderBy: { balance: 'desc' }, select: { fullName: true, balance: true } });
    if (!owed.length) return '💰 Сейчас никому ничего не должны.';
    const total = owed.reduce((a, w) => a + w.balance, 0n);
    return [`💰 К выплате всего: ${sum(total)} (${owed.length} мастериц)`, ...owed.slice(0, 7).map((w) => `• ${w.fullName}: ${sum(w.balance)}`), owed.length > 7 ? `…и ещё ${owed.length - 7}` : ''].filter(Boolean).join('\n');
  }

  private async works(now: Date) {
    const [by, overdue] = await Promise.all([
      this.prisma.workAssignment.groupBy({ by: ['status'], where: { status: { in: [...OPEN] } }, _count: { _all: true } }),
      this.prisma.workAssignment.count({ where: { status: { in: ['READY_TO_DELIVER', 'DELIVERED', 'IN_PROGRESS'] }, dueAt: { lt: now } } }),
    ]);
    if (!by.length) return '🧵 Открытых работ нет.';
    const total = by.reduce((a, g) => a + g._count._all, 0);
    return [`🧵 Открытых работ: ${total}`, ...OPEN.flatMap((s) => { const g = by.find((x) => x.status === s); return g ? [`• ${STATUS_RU[s]}: ${g._count._all}`] : []; }), overdue ? `⚠️ Просрочено: ${overdue}` : '✅ Просроченных нет'].join('\n');
  }

  private async server() {
    const lines = ['🖥 Сервер'];
    try {
      const t = Date.now();
      await this.prisma.$queryRaw`SELECT 1`;
      lines.push(`База данных: работает (${Date.now() - t} мс)`);
    } catch {
      lines.push('База данных: НЕ отвечает');
    }
    const file = this.env.RELEASE_MANIFEST;
    if (file) {
      try {
        const s = await statfs(dirname(file));
        const free = s.bavail * s.bsize, total = s.blocks * s.bsize;
        lines.push(`Свободно на диске: ${(free / 1024 ** 3).toFixed(0)} ГБ из ${(total / 1024 ** 3).toFixed(0)} ГБ (${Math.round((free / total) * 100)}%)`);
      } catch {/* not mounted */}
      try {
        const j = JSON.parse(await readFile(file, 'utf8')) as { version?: string };
        if (j.version) lines.push(`Приложение: ${j.version}`);
      } catch {/* not published yet */}
    }
    lines.push(`Работает без перезапуска: ${Math.floor(process.uptime() / 3600)} ч`);
    return lines.join('\n');
  }
}
