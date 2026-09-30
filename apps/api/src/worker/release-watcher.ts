import { Inject, Injectable, Logger } from '@nestjs/common';
import { readFile } from 'node:fs/promises';
import { ENV, Env } from '../config/env';
import { EventBus } from '../events/event-bus';
import { PushService } from '../notifications/push.service';
import { RedisService } from '../redis/redis.module';

const KEY = 'app:release:announced';

/**
 * A new Android build was published (infra/scripts/publish-apk.sh writes downloads/version.json): tell every phone at once,
 * whatever version it runs - a push «Доступно обновление» (a tap opens the app, which then downloads it) and a realtime
 * hint so an open app checks right away. Each build is announced once (Redis remembers the last one).
 */
@Injectable()
export class ReleaseWatcher {
  private readonly log = new Logger('Release');
  constructor(@Inject(ENV) private readonly env: Env, private readonly redis: RedisService, private readonly bus: EventBus, private readonly push: PushService) {}

  async tick(): Promise<{ build: number; version: string } | null> {
    const file = this.env.RELEASE_MANIFEST;
    if (!file || !this.redis.client) return null;
    let j: { build?: unknown; version?: unknown };
    try {
      j = JSON.parse(await readFile(file, 'utf8')) as typeof j;
    } catch {
      return null; // not published yet / being replaced
    }
    const build = typeof j.build === 'number' ? j.build : NaN;
    const version = typeof j.version === 'string' ? j.version : '';
    if (!Number.isInteger(build) || !version) return null;
    const last = Number(await this.redis.client.get(KEY));
    if (Number.isFinite(last) && last >= build) return null;
    await this.redis.client.set(KEY, String(build));
    this.log.log(`announcing ${version} (build ${build})`);
    await this.bus.publish('app.release', { build, version });
    await this.push.sendAll({ id: `release-${build}`, title: 'Доступно обновление Diamoraa', body: `Версия ${version}. Нажмите — приложение обновится.`, kind: 'update' });
    return { build, version };
  }
}
