import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { faststart } from '../src/chat/faststart';

/** ffmpeg on this machine: the server image has it (apt), a developer's PC may have it from tools/tutorials. */
const candidates = [process.env.FFMPEG_PATH, resolve(__dirname, '../../../tools/tutorials/node_modules/ffmpeg-static/ffmpeg.exe'), resolve(__dirname, '../../../tools/tutorials/node_modules/ffmpeg-static/ffmpeg')];
const ffmpeg = candidates.find((p) => p && existsSync(p));
const moovFirst = (b: Buffer) => b.indexOf('moov') !== -1 && b.indexOf('moov') < b.indexOf('mdat');

describe('phone videos start playing at once: the index goes to the front (faststart)', () => {
  (ffmpeg ? it : it.skip)('a video with the index at the end comes back with it at the front, same size order', async () => {
    const src = join(tmpdir(), `fs-test-${Date.now()}.mp4`);
    // like a phone: the index («moov») written last
    const made = spawnSync(ffmpeg!, ['-v', 'error', '-y', '-f', 'lavfi', '-i', 'testsrc=duration=2:size=320x240:rate=15', '-c:v', 'mpeg4', '-f', 'mp4', src]);
    expect(made.status).toBe(0);
    const input = readFileSync(src);
    expect(moovFirst(input)).toBe(false);

    const out = await faststart({ buffer: input }, ffmpeg!);
    expect(out).not.toBeNull();
    const fixed = readFileSync(out!.path);
    expect(moovFirst(fixed)).toBe(true);
    expect(out!.size).toBe(fixed.length);
    await out!.cleanup();
    expect(existsSync(out!.path)).toBe(false);
  });

  it('no ffmpeg / not a video -> null (the original is stored as before)', async () => {
    expect(await faststart({ buffer: Buffer.from('not a video at all') }, ffmpeg ?? 'ffmpeg-that-does-not-exist')).toBeNull();
    expect(await faststart({ buffer: Buffer.from('x') }, 'ffmpeg-that-does-not-exist')).toBeNull();
  });
});
