/**
 * Recovery tool for a lost staff password (SUPER_ADMIN/ADMIN/MANAGER) when there is no other admin session to do it
 * through the app itself (POST /users/:id/reset-password, users.service.ts:resetPassword — this mirrors that exact
 * logic: new random password, argon2id hash, audit log, all active sessions revoked). Deliberately explicit and hard
 * to run by accident, same as promote-owner.js: the phone must be typed twice, identically.
 *   node dist/cli/reset-password.js --phone "+998901234567" --confirm-phone "+998901234567"
 * A new password is printed once and is not recoverable afterwards — save it immediately.
 */
import 'reflect-metadata';
import * as argon2 from 'argon2';
import { PrismaClient } from '@yusmus/database';
import { normalizePhone } from '@yusmus/shared';
import { randomInt } from 'node:crypto';

const arg = (n: string) => { const i = process.argv.indexOf(`--${n}`); return i >= 0 ? process.argv[i + 1] : undefined; };
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
const generatePassword = () => Array.from({ length: 14 }, () => ALPHABET[randomInt(ALPHABET.length)]).join('');

async function main() {
  const phone = normalizePhone(arg('phone') ?? '');
  const confirm = normalizePhone(arg('confirm-phone') ?? '');
  if (!phone || !confirm) { console.error('Usage: --phone <phone> --confirm-phone <same phone>'); process.exit(2); }
  if (phone !== confirm) { console.error('--phone and --confirm-phone do not match — nothing done.'); process.exit(2); }
  const prisma = new PrismaClient();
  try {
    const user = await prisma.user.findUnique({ where: { phone } });
    if (!user) { console.error(`No user with phone ${phone} — nothing done.`); process.exit(1); }
    if (user.role === 'WORKER') { console.error('Workers sign in with a Telegram code, they have no password.'); process.exit(1); }
    const password = generatePassword();
    const passwordHash = await argon2.hash(password, { type: argon2.argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1 });
    await prisma.$transaction([
      prisma.user.update({ where: { id: user.id }, data: { passwordHash } }),
      prisma.userSession.updateMany({ where: { userId: user.id, revokedAt: null }, data: { revokedAt: new Date(), revokedReason: 'password_reset' } }),
      prisma.auditLog.create({ data: { actorId: user.id, actorRole: user.role, action: 'user.password_reset', entity: 'User', entityId: user.id } }),
    ]);
    console.log(`Password reset for ${phone} (${user.fullName}, ${user.role}).`);
    console.log(`New password (shown once): ${password}`);
  } finally {
    await prisma.$disconnect();
  }
}
main().catch((e) => { console.error(e); process.exit(1); });
