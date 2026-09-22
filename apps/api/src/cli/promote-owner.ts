/**
 * Migration helper for an EXISTING deployment that predates SUPER_ADMIN (D-028 §9): promotes one already-existing staff
 * account (ADMIN or MANAGER) to SUPER_ADMIN. Deliberately explicit and hard to run by accident:
 *   - the phone must be typed twice, identically (--phone and --confirm-phone) — no tab-completion accident;
 *   - the account must already exist with role ADMIN or MANAGER (this never creates an account, never touches WORKER);
 *   - every promotion is one more audit row (user.promote_to_super_admin); nothing else changes for the account.
 *   node dist/cli/promote-owner.js --phone "+998901234567" --confirm-phone "+998901234567"
 */
import 'reflect-metadata';
import { PrismaClient } from '@yusmus/database';
import { normalizePhone } from '@yusmus/shared';

const arg = (n: string) => { const i = process.argv.indexOf(`--${n}`); return i >= 0 ? process.argv[i + 1] : undefined; };

async function main() {
  const phone = normalizePhone(arg('phone') ?? '');
  const confirm = normalizePhone(arg('confirm-phone') ?? '');
  if (!phone || !confirm) { console.error('Usage: --phone <phone> --confirm-phone <same phone>'); process.exit(2); }
  if (phone !== confirm) { console.error('--phone and --confirm-phone do not match — nothing done.'); process.exit(2); }
  const prisma = new PrismaClient();
  try {
    const user = await prisma.user.findUnique({ where: { phone } });
    if (!user) { console.error(`No user with phone ${phone} — this script never creates an account (use bootstrap.js for a brand new database).`); process.exit(1); }
    if (user.role === 'SUPER_ADMIN') { console.log(`${phone} is already SUPER_ADMIN — nothing to do.`); return; }
    if (user.role !== 'ADMIN' && user.role !== 'MANAGER') { console.error(`${phone} has role ${user.role}: only an existing ADMIN or MANAGER can be promoted to SUPER_ADMIN.`); process.exit(1); }
    await prisma.$transaction([
      prisma.user.update({ where: { id: user.id }, data: { role: 'SUPER_ADMIN' } }),
      prisma.userPermission.deleteMany({ where: { userId: user.id } }), // SUPER_ADMIN has every permission; per-user overrides are meaningless now
      prisma.userSession.updateMany({ where: { userId: user.id, revokedAt: null }, data: { revokedAt: new Date(), revokedReason: 'promoted_to_super_admin' } }),
      prisma.auditLog.create({ data: { actorId: user.id, actorRole: 'SUPER_ADMIN', action: 'user.promote_to_super_admin', entity: 'User', entityId: user.id, before: { role: user.role }, after: { role: 'SUPER_ADMIN' } } }),
    ]);
    console.log(`${phone} (${user.fullName}) is now SUPER_ADMIN. Their existing sessions were revoked — they must sign in again.`);
  } finally {
    await prisma.$disconnect();
  }
}
main().catch((e) => { console.error(e); process.exit(1); });
