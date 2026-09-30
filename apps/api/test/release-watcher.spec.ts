import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ReleaseWatcher } from '../src/worker/release-watcher';

/** A newly published app build is announced to every phone once: a push + a realtime hint. */
describe('release watcher', () => {
  const dir = mkdtempSync(join(tmpdir(), 'rel-'));
  const file = join(dir, 'version.json');
  const store = new Map<string, string>();
  const redis = { client: { get: async (k: string) => store.get(k) ?? null, set: async (k: string, v: string) => void store.set(k, v) } };
  const events: unknown[] = [];
  const pushes: { id: string; kind?: string; body?: string | null }[] = [];
  const bus = { publish: async (type: string, data: unknown) => void events.push({ type, data }) };
  const push = { sendAll: async (n: { id: string; kind?: string; body?: string | null }) => void pushes.push(n) };
  const w = new ReleaseWatcher({ RELEASE_MANIFEST: file } as never, redis as never, bus as never, push as never);

  it('nothing published yet -> nothing sent', async () => {
    expect(await w.tick()).toBeNull();
    expect(pushes).toHaveLength(0);
  });

  it('a new build -> one push to all phones and an app.release event; the same build is not announced twice', async () => {
    writeFileSync(file, JSON.stringify({ version: '1.0.0-rc.37', build: 37 }));
    expect(await w.tick()).toEqual({ build: 37, version: '1.0.0-rc.37' });
    expect(events).toEqual([{ type: 'app.release', data: { build: 37, version: '1.0.0-rc.37' } }]);
    expect(pushes).toEqual([expect.objectContaining({ id: 'release-37', kind: 'update', body: expect.stringContaining('1.0.0-rc.37') })]);
    expect(await w.tick()).toBeNull();
    expect(pushes).toHaveLength(1);
  });

  it('the next build is announced; a broken manifest (mid-write) is skipped', async () => {
    writeFileSync(file, '{"version":');
    expect(await w.tick()).toBeNull();
    writeFileSync(file, JSON.stringify({ version: '1.0.0-rc.38', build: 38 }));
    expect(await w.tick()).toEqual({ build: 38, version: '1.0.0-rc.38' });
    expect(pushes.map((p) => p.id)).toEqual(['release-37', 'release-38']);
  });
});
