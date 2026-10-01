// The app on the Android emulator: find things on screen by their text (uiautomator; Flutter exposes its semantics),
// tap / type through adb, record the screen with the emulator's own recorder (touches are shown by Android), and the same
// caption timeline -> uz + ru MP4 as the web videos.
import { spawnSync } from 'node:child_process';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import ffmpegPath from 'ffmpeg-static';
import { LANGS, OUT, render } from './lib.mjs';

export const PKG = 'uz.diamoraa.app';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
export const adb = (...args) => {
  // the emulator's adb link drops a command now and then: try again before giving up
  for (let i = 0; ; i++) {
    const r = spawnSync('adb', args, { encoding: 'utf8', maxBuffer: 64 << 20 });
    if (r.status === 0) return r.stdout;
    if (i === 2) throw new Error(`adb ${args.join(' ')}: ${r.stderr}`);
    spawnSync('node', ['-e', 'setTimeout(()=>{},700)']);
  }
};

/** every node on screen with a label: { label, x, y, w, h } (device pixels) */
export function screen() {
  let xml = '';
  for (let i = 0; i < 4 && !xml.includes('<hierarchy'); i++) {
    try { xml = adb('exec-out', 'uiautomator', 'dump', '/dev/tty'); } catch { /* the screen is busy: retry */ }
  }
  const nodes = [];
  for (const m of xml.matchAll(/<node [^>]*?text="([^"]*)"[^>]*?content-desc="([^"]*)"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/g)) {
    const label = (m[1] || m[2]).replace(/&#10;/g, '\n').replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&#39;/g, "'");
    if (!label) continue;
    const [x1, y1, x2, y2] = [m[3], m[4], m[5], m[6]].map(Number);
    nodes.push({ label, x: (x1 + x2) / 2, y: (y1 + y2) / 2, w: x2 - x1, h: y2 - y1 });
  }
  return nodes;
}

const matches = (label, q) => (q instanceof RegExp ? q.test(label) : label === q || label.split('\n')[0] === q);

export async function find(q, { timeout = 25000, last = false } = {}) {
  const until = Date.now() + timeout;
  for (;;) {
    const now = screen();
    // the emulator's software graphics sometimes trip Android's «isn't responding» box: just wait
    const wait = now.find((n) => n.label === 'Wait' && now.some((m) => /isn.t responding/.test(m.label)));
    if (wait) { adb('shell', 'input', 'tap', String(wait.x), String(wait.y)); await sleep(1500); continue; }
    const all = now.filter((n) => matches(n.label, q));
    if (all.length) return last ? all[all.length - 1] : all[0];
    if (Date.now() > until) throw new Error(`not on screen: ${q}\n${screen().map((n) => n.label.split('\n')[0]).join(' | ')}`);
    await sleep(700);
  }
}

export async function recordApp({ name, size = { width: 720, height: 1600 }, script, setup }) {
  mkdirSync(OUT, { recursive: true });
  if (setup) await setup();
  // recorded by the emulator itself, straight to the computer (the phone's own screenrecord drops frames here)
  const tmp = join(OUT, `.rec-${name}`);
  mkdirSync(tmp, { recursive: true });
  // the emulator records at most 3 minutes at a time: a new part every 2.5 minutes, joined afterwards
  const fwd = (f) => f.split('\\').join('/');
  const parts = [];
  const startPart = () => {
    const file = resolve(tmp, `part-${parts.length}.webm`);
    rmSync(file, { force: true });
    adb('emu', 'screenrecord', 'start', '--time-limit', '180', fwd(file));
    parts.push({ file, start: Date.now() / 1000 });
  };
  startPart();
  await sleep(800);
  const t0 = parts[0].start;
  const captions = [];
  const at = () => Date.now() / 1000 - t0;
  const rotate = setInterval(() => {
    try { adb('emu', 'screenrecord', 'stop'); } catch { /* ended */ }
    spawnSync('node', ['-e', 'setTimeout(()=>{},1500)']); // the part is finished
    startPart();
  }, 150_000);
  // a caption without a hold waits for the next action: it shows when the thing happens on screen (finding a button
  // on a busy emulator can take seconds), and the action follows a moment later so it can be read first
  let pending = null;
  const flush = async () => { if (pending) { captions.push({ start: at(), text: pending }); pending = null; await sleep(1300); } };
  const h = {
    async say(text, holdMs = 0) {
      if (!holdMs) { await flush(); pending = text; return; }
      await flush();
      captions.push({ start: at(), text });
      await sleep(holdMs);
    },
    async pause(ms = 1500) { await flush(); await sleep(ms); },
    find,
    async tap(q, opts = {}) {
      const n = await find(q, opts);
      await flush();
      await sleep(opts.before ?? 500);
      adb('shell', 'input', 'tap', String(Math.round(n.x + (opts.dx ?? 0))), String(Math.round(n.y + (opts.dy ?? 0))));
      await sleep(opts.after ?? 1500);
    },
    /** taps it only when it shows up within `timeout` (screens that appear only on some phones) */
    async tapIfShown(q, opts = {}) {
      try { await find(q, { timeout: opts.timeout ?? 6000 }); } catch { return false; }
      await h.tap(q, opts);
      return true;
    },
    async tapAt(x, y, after = 1500) { await flush(); adb('shell', 'input', 'tap', String(x), String(y)); await sleep(after); },
    /** Latin letters, digits and spaces only (adb cannot type Cyrillic) */
    async type(text, after = 800) {
      await flush();
      for (const word of text.split(' ')) {
        if (word) adb('shell', 'input', 'text', word.replace(/'/g, "\\'"));
        if (word !== text.split(' ').at(-1)) adb('shell', 'input', 'keyevent', '62');
        await sleep(120);
      }
      await sleep(after);
    },
    /** plays the bot's «START» for this worker (the emulator has no Telegram), then opens the app by the bot's link */
    async telegramStart(phone, after = 4000) {
      await flush();
      const r = await fetch(`http://localhost:3000/demo/worker-login?phone=${encodeURIComponent(phone)}`, { method: 'POST' });
      const j = await r.json();
      if (!j.handoffUrl) throw new Error('no demo login session');
      const t = new URL(j.handoffUrl).searchParams.get('t');
      adb('shell', `am start -a android.intent.action.VIEW -d 'https://diamoraa.uz/app/auth/telegram?t=${t}' ${PKG}`);
      await sleep(after);
    },
    async clearField(n = 12) { adb('shell', 'input', 'keyevent', '123'); for (let i = 0; i < n; i++) adb('shell', 'input', 'keyevent', '67'); await sleep(300); },
    async back(after = 1200) { await flush(); adb('shell', 'input', 'keyevent', '4'); await sleep(after); },
    async hideKeyboard(after = 600) { try { adb('shell', 'input', 'keyevent', '111'); } catch { /* none */ } await sleep(after); },
    async swipeUp(dy = 900, after = 1200) { await flush(); adb('shell', 'input', 'swipe', '540', '1700', '540', String(1700 - dy), '450'); await sleep(after); },
    async swipeDown(dy = 900, after = 1200) { await flush(); adb('shell', 'input', 'swipe', '540', '700', '540', String(700 + dy), '450'); await sleep(after); },
  };
  try {
    await script(h);
    await flush();
    await sleep(2500);
  } finally {
    clearInterval(rotate);
    captions.push({ start: at(), text: null });
    try { adb('emu', 'screenrecord', 'stop'); } catch { /* ended by itself */ }
    await sleep(4000); // the file is finished a moment after stop
  }
  // join the parts; each caption moves into the joined video (the second between two parts is not in it)
  const durOf = (f) => {
    const d = /Duration: (\d+):(\d+):([\d.]+)/.exec(spawnSync(ffmpegPath, ['-hide_banner', '-i', f], { encoding: 'utf8' }).stderr);
    return d ? Number(d[1]) * 3600 + Number(d[2]) * 60 + Number(d[3]) : 0;
  };
  let acc = 0;
  for (const p of parts) { p.offset = acc; p.rel = p.start - t0; p.dur = durOf(p.file); acc += p.dur; }
  for (const c of captions) {
    const p = [...parts].reverse().find((x) => c.start >= x.rel) ?? parts[0];
    c.start = p.offset + Math.min(c.start - p.rel, p.dur);
  }
  const list = resolve(tmp, 'parts.txt');
  writeFileSync(list, parts.map((p) => `file '${fwd(p.file)}'`).join('\n'));
  const raw = resolve(tmp, 'raw.webm');
  spawnSync(ffmpegPath, ['-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', list, '-c', 'copy', raw]);
  console.log(`  ${parts.length} part(s), ${acc.toFixed(0)} s`);
  for (const lang of LANGS) render(raw, captions, lang, join(OUT, `${name}-${lang}.mp4`), size);
  return captions;
}

/** a clean start: the app's data wiped, the app opened */
export async function freshApp() {
  // awake for the whole recording
  adb('shell', 'input', 'keyevent', '224');
  adb('shell', 'svc', 'power', 'stayon', 'true');
  adb('shell', 'settings', 'put', 'system', 'screen_off_timeout', '2147483647');
  try { adb('shell', 'am', 'force-stop', 'com.android.chrome'); } catch { /* not running */ }
  adb('shell', 'pm', 'clear', PKG);
  adb('shell', 'pm', 'grant', PKG, 'android.permission.ACCESS_FINE_LOCATION');
  adb('shell', 'pm', 'grant', PKG, 'android.permission.ACCESS_COARSE_LOCATION');
  try { adb('shell', 'pm', 'grant', PKG, 'android.permission.POST_NOTIFICATIONS'); } catch { /* older */ }
  try { adb('shell', 'pm', 'grant', PKG, 'android.permission.CAMERA'); } catch { /* not declared */ }
  // open it (again if the first start after a wipe is lost) until the login screen is up
  for (let i = 0; ; i++) {
    adb('shell', 'am', 'start', '-n', `${PKG}/.MainActivity`);
    try { await find("O'zbek", { timeout: 40000 }); break; } catch (e) { if (i === 2) throw e; }
  }
  await sleep(1500);
}
