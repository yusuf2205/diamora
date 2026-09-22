/**
 * First run on a FRESH database: creates the owner's account as SUPER_ADMIN (D-028 §9: the main administrator is the one
 * unambiguous, explicit case that becomes SUPER_ADMIN — there is nobody else it could be, since the database is empty).
 *   node dist/cli/bootstrap.js --name "Owner Name" --phone "+998901234567" [--password "..."] [--role ADMIN]
 * A generated password is printed once. Refuses if the phone already exists, or if the database already has a SUPER_ADMIN
 * (use `promote-owner.js` on an existing deployment instead — this script is for a brand new one only).
 */
import 'reflect-metadata';
import * as argon2 from 'argon2';
import { PrismaClient } from '@yusmus/database';
import { normalizePhone, STAFF_ROLES, type StaffRole } from '@yusmus/shared';
import { randomInt } from 'node:crypto';

const arg = (n: string) => { const i = process.argv.indexOf(`--${n}`); return i >= 0 ? process.argv[i + 1] : undefined; };
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';

async function main() {
  const name = arg('name');
  const phone = normalizePhone(arg('phone') ?? '');
  const role = (arg('role') ?? 'SUPER_ADMIN') as StaffRole;
  if (!name || !phone) { console.error('Usage: --name <full name> --phone <phone> [--password <pw>] [--role SUPER_ADMIN|ADMIN|MANAGER]'); process.exit(2); }
  if (!(STAFF_ROLES as readonly string[]).includes(role)) { console.error(`--role must be one of ${STAFF_ROLES.join(', ')}`); process.exit(2); }
  const password = arg('password') ?? Array.from({ length: 14 }, () => ALPHABET[randomInt(ALPHABET.length)]).join('');
  if (password.length < 8) { console.error('Password must be at least 8 characters'); process.exit(2); }
  const prisma = new PrismaClient();
  try {
    if (role === 'SUPER_ADMIN') {
      const existing = await prisma.user.count({ where: { role: 'SUPER_ADMIN' } });
      if (existing > 0) { console.error(`This database already has ${existing} SUPER_ADMIN account(s). Use "node dist/cli/promote-owner.js" to add another one explicitly, or pass --role ADMIN/MANAGER here.`); process.exit(1); }
    }
    if (await prisma.user.findUnique({ where: { phone } })) { console.error(`A user with phone ${phone} already exists — nothing done.`); process.exit(1); }
    const passwordHash = await argon2.hash(password, { type: argon2.argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1 });
    const user = await prisma.user.create({ data: { phone, fullName: name, role, passwordHash } });
    await prisma.auditLog.create({ data: { actorId: user.id, actorRole: role, action: 'user.bootstrap', entity: 'User', entityId: user.id, after: { role } } });
    console.log(`${role} created: ${phone}`);
    if (!arg('password')) console.log(`Password (shown once): ${password}`);
  } finally {
    await prisma.$disconnect();
  }
}
main().catch((e) => { console.error(e); process.exit(1); });
