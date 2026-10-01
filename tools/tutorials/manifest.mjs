// out/tutorials.json + a poster per video: what the app, the panel, the shop and the shop bot read
// (published next to the APK under /download/tutorials/ by publish.sh).
import ffmpegPath from 'ffmpeg-static';
import { spawnSync } from 'node:child_process';
import { existsSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { LANGS, OUT } from './lib.mjs';

const ORDER = ['worker', 'manager', 'admin', 'superadmin', 'customer'];
const BASE = '/download/tutorials';
const duration = (file) => {
  const m = /Duration: (\d+):(\d+):([\d.]+)/.exec(spawnSync(ffmpegPath, ['-hide_banner', '-i', file], { encoding: 'utf8' }).stderr);
  return m ? Math.round(Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3])) : null;
};

const items = [];
for (const name of ORDER) {
  const v = (await import(`./videos/${name}.mjs`)).default;
  const files = Object.fromEntries(LANGS.filter((l) => existsSync(join(OUT, `${name}-${l}.mp4`))).map((l) => [l, `${BASE}/${name}-${l}.mp4`]));
  if (!Object.keys(files).length) continue;
  const first = join(OUT, `${name}-${Object.keys(files)[0]}.mp4`);
  const seconds = duration(first);
  // the poster: a frame a third of the way in, the caption band cut off
  spawnSync(ffmpegPath, ['-y', '-loglevel', 'error', '-ss', String(Math.round((seconds ?? 30) / 3)), '-i', first, '-frames:v', '1', '-vf', 'crop=iw:ih*0.86:0:0,scale=960:-2', '-q:v', '4', join(OUT, `${name}.jpg`)]);
  items.push({ id: name, roles: v.roles, title: v.title, files, poster: `${BASE}/${name}.jpg`, seconds });
}
writeFileSync(join(OUT, 'tutorials.json'), JSON.stringify({ updatedAt: new Date().toISOString(), items }, null, 1));
console.log(`tutorials.json: ${items.map((i) => `${i.id} (${i.seconds}s)`).join(', ')}`);
