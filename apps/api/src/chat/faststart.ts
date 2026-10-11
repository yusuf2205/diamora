import { spawn } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import { createReadStream, createWriteStream } from 'node:fs';
import { rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pipeline } from 'node:stream/promises';

/**
 * A phone writes the video's index («moov») at the END of the file, so a player has to fetch almost everything before
 * the first frame (owner, 2026-10-11: «долго загружается видео»). `ffmpeg -c copy -movflags +faststart` moves it to the
 * front - no re-encoding, the same picture, a few seconds of work - and the video starts while it is still downloading.
 * Any trouble (no ffmpeg, an odd file, a timeout) -> null, and the original is stored as before.
 */
export async function faststart(input: { buffer?: Buffer; parts?: string[] }, ffmpeg = process.env.FFMPEG_PATH ?? 'ffmpeg', timeoutMs = 90_000): Promise<{ path: string; size: number; sha256: string; cleanup: () => Promise<void> } | null> {
  const id = randomUUID();
  const src = join(tmpdir(), `fs-${id}-in.mp4`);
  const out = join(tmpdir(), `fs-${id}-out.mp4`);
  const cleanup = async () => { await rm(src, { force: true }); await rm(out, { force: true }); };
  try {
    if (input.buffer) await writeFile(src, input.buffer);
    else if (input.parts?.length) {
      const w = createWriteStream(src);
      for (const p of input.parts) await pipeline(createReadStream(p), w, { end: false });
      await new Promise<void>((resolve, reject) => w.end((e?: Error | null) => (e ? reject(e) : resolve())));
    } else return null;
    const ok = await new Promise<boolean>((resolve) => {
      const p = spawn(ffmpeg, ['-v', 'error', '-y', '-i', src, '-map', '0', '-c', 'copy', '-movflags', '+faststart', '-f', 'mp4', out], { stdio: 'ignore' });
      const t = setTimeout(() => { p.kill('SIGKILL'); resolve(false); }, timeoutMs);
      p.on('error', () => { clearTimeout(t); resolve(false); });
      p.on('close', (code) => { clearTimeout(t); resolve(code === 0); });
    });
    if (!ok) { await cleanup(); return null; }
    const size = (await stat(out)).size;
    if (size === 0) { await cleanup(); return null; }
    const hash = createHash('sha256');
    for await (const chunk of createReadStream(out)) hash.update(chunk as Buffer);
    return { path: out, size, sha256: hash.digest('hex'), cleanup };
  } catch {
    await cleanup();
    return null;
  }
}
