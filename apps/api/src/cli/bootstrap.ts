/**
 * First run: creates the ADMIN account.
 *   node dist/cli/bootstrap.js --name "Owner Name" --phone "+998901234567" [--password "..."]
 * A generated password is printed once. Refuses if the phone already exists.
 */
import 'reflect-metadata';
import * as argon2 from 'argon2';
import { PrismaClient } from '@yusmus/database';
import { normalizePhone } from '@yusmus/shared';
import { randomInt } from 'node:crypto';

const arg = (n: string) => { const i = process.argv.indexOf(`--${n}`); return i >= 0 ? process.argv[i + 1] : undefined; };
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';

async function main() {
  const name = arg('name');
  const phone = normalizePhone(arg('phone') ?? '');
  if (!name || !phone) { console.error('Usage: --name <full name> --phone <phone> [--password <pw>]'); process.exit(2); }
  const password = arg('password') ?? Array.from({ length: 14 }, () => ALPHABET[randomInt(ALPHABET.length)]).join('');
  if (password.length < 8) { console.error('Password must be at least 8 characters'); process.exit(2); }
  const prisma = new PrismaClient();
  try {
    if (await prisma.user.findUnique({ where: { phone } })) { console.error(`A user with phone ${phone} already exists — nothing done.`); process.exit(1); }
    const passwordHash = await argon2.hash(password, { type: argon2.argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1 });
    const user = await prisma.user.create({ data: { phone, fullName: name, role: 'ADMIN', passwordHash } });
    await prisma.auditLog.create({ data: { actorId: user.id, actorRole: 'ADMIN', action: 'admin.bootstrap', entity: 'User', entityId: user.id } });
    console.log(`ADMIN created: ${phone}`);
    if (!arg('password')) console.log(`Password (shown once): ${password}`);
  } finally {
    await prisma.$disconnect();
  }
}
main().catch((e) => { console.error(e); process.exit(1); });
