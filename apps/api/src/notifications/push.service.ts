import { Inject, Injectable, Logger } from '@nestjs/common';
import { createSign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { ENV, type Env } from '../config/env';
import { PrismaService } from '../prisma/prisma.module';

interface ServiceAccount { project_id: string; client_email: string; private_key: string; token_uri: string }
export interface PushNotice { id: string; title: string; body?: string | null; link?: string | null }

const b64url = (v: Buffer | string) => Buffer.from(v).toString('base64url');

/**
 * Instant Android notifications through Firebase Cloud Messaging (HTTP v1), with no SDK: a service-account JWT is signed
 * here (RS256), exchanged for a short-lived access token (cached), and each notice goes to every device the user signed
 * in on. The message is DATA-ONLY on purpose: the app shows it itself under the notice's own id, so the same notice
 * arriving again through the realtime socket or the 15-minute background check replaces it instead of doubling it.
 * Without FIREBASE_CREDENTIALS_FILE everything here is a no-op (the in-app bell and the background check still work).
 * A token Firebase reports as gone (app uninstalled, data cleared) is deleted.
 */
@Injectable()
export class PushService {
  private readonly log = new Logger('Push');
  private readonly account: ServiceAccount | null;
  private token: { value: string; exp: number } | null = null;

  constructor(private readonly prisma: PrismaService, @Inject(ENV) env: Env) {
    this.account = null;
    if (env.FIREBASE_CREDENTIALS_FILE) {
      try {
        const j = JSON.parse(readFileSync(env.FIREBASE_CREDENTIALS_FILE, 'utf8')) as ServiceAccount;
        if (j.project_id && j.client_email && j.private_key) this.account = { ...j, token_uri: j.token_uri || 'https://oauth2.googleapis.com/token' };
      } catch (e) {
        this.log.warn(`push disabled: cannot read the Firebase credentials (${(e as Error).message})`);
      }
    }
  }

  get enabled() { return this.account !== null; }

  async register(userId: string, token: string, platform: string) {
    await this.prisma.pushToken.upsert({ where: { token }, create: { userId, token, platform }, update: { userId, platform } });
    return { ok: true };
  }

  async unregister(userId: string, token: string) {
    await this.prisma.pushToken.deleteMany({ where: { userId, token } });
    return { ok: true };
  }

  /** Fire-and-forget from the caller's point of view: a push failure never fails the action that caused it. */
  async send(userId: string, n: PushNotice) {
    if (!this.account) return;
    const tokens = await this.prisma.pushToken.findMany({ where: { userId }, select: { token: true } });
    if (!tokens.length) return;
    let access: string;
    try {
      access = await this.accessToken();
    } catch (e) {
      this.log.warn(`push: no access token (${(e as Error).message})`);
      return;
    }
    const url = `https://fcm.googleapis.com/v1/projects/${this.account.project_id}/messages:send`;
    await Promise.all(tokens.map(async ({ token }) => {
      try {
        const res = await fetch(url, {
          method: 'POST',
          headers: { Authorization: `Bearer ${access}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            message: {
              token,
              data: { id: n.id, title: n.title, body: n.body ?? '', link: n.link ?? '' },
              android: { priority: 'HIGH', ttl: '86400s' },
            },
          }),
        });
        if (res.ok) return;
        const text = await res.text();
        if (res.status === 404 || /UNREGISTERED|registration-token-not-registered|INVALID_ARGUMENT/.test(text)) {
          await this.prisma.pushToken.deleteMany({ where: { token } });
        } else {
          this.log.warn(`push ${res.status}: ${text.slice(0, 200)}`);
        }
      } catch (e) {
        this.log.warn(`push: ${(e as Error).message}`);
      }
    }));
  }

  private async accessToken(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    if (this.token && this.token.exp - 60 > now) return this.token.value;
    const a = this.account!;
    const unsigned = `${b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))}.${b64url(JSON.stringify({
      iss: a.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: a.token_uri, iat: now, exp: now + 3600,
    }))}`;
    const signature = createSign('RSA-SHA256').update(unsigned).sign(a.private_key);
    const res = await fetch(a.token_uri, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${unsigned}.${b64url(signature)}` }),
    });
    if (!res.ok) throw new Error(`token ${res.status}`);
    const j = (await res.json()) as { access_token: string; expires_in: number };
    this.token = { value: j.access_token, exp: now + (j.expires_in ?? 3600) };
    return this.token.value;
  }
}
