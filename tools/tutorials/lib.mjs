// Shared recorder: a visible cursor + a ring around what is pressed (in the page, so it is in the video), a timeline of
// captions, and the final MP4 per language with the captions burnt in (one recording -> uz + ru).
import { chromium } from 'playwright';
import ffmpegPath from 'ffmpeg-static';
import { spawnSync } from 'node:child_process';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

export const WEB = process.env.WEB ?? 'http://localhost:3001';
export const OUT = resolve(process.env.OUT_DIR ?? 'out');
export const LANGS = ['uz', 'ru'];

// ---- in-page overlay: cursor + highlight ring (no text: captions are added per language afterwards) -----------------------
const OVERLAY = () => {
  const boot = () => {
    if (document.getElementById('__cur')) return;
    const st = document.createElement('style');
    st.textContent = `
      #__cur{position:fixed;left:-50px;top:-50px;width:26px;height:26px;margin:-13px 0 0 -13px;border-radius:50%;
        background:rgba(163,50,79,.35);border:3px solid #A3324F;z-index:2147483647;pointer-events:none;
        transition:left .7s cubic-bezier(.4,0,.2,1),top .7s cubic-bezier(.4,0,.2,1),transform .15s}
      #__cur.down{transform:scale(.7)}
      #__ring{position:fixed;border:4px solid #F2A900;border-radius:14px;z-index:2147483646;pointer-events:none;
        box-shadow:0 0 0 6px rgba(242,169,0,.25);opacity:0;transition:opacity .25s}
      #__ring.on{opacity:1;animation:__p 0.9s ease-in-out infinite}
      @keyframes __p{50%{box-shadow:0 0 0 12px rgba(242,169,0,.12)}}`;
    document.documentElement.appendChild(st);
    const c = document.createElement('div'); c.id = '__cur'; document.documentElement.appendChild(c);
    const r = document.createElement('div'); r.id = '__ring'; document.documentElement.appendChild(r);
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.__demo = {
    move(x, y) { boot(); const c = document.getElementById('__cur'); c.style.left = `${x}px`; c.style.top = `${y}px`; },
    ring(b) { boot(); const r = document.getElementById('__ring'); if (!b) { r.className = ''; return; }
      Object.assign(r.style, { left: `${b.x - 8}px`, top: `${b.y - 8}px`, width: `${b.width + 16}px`, height: `${b.height + 16}px` }); r.className = 'on'; },
    press(on) { document.getElementById('__cur')?.classList.toggle('down', on); },
  };
};

/**
 * Records one web video. `script(h)` drives the page with the helpers below; every `h.say({uz, ru})` starts a caption
 * that lasts until the next one. Writes out/<name>-<lang>.mp4 for every language.
 */
export async function recordWeb({ name, viewport = { width: 1280, height: 800 }, mobile = false, script }) {
  mkdirSync(OUT, { recursive: true });
  const tmp = join(OUT, `.rec-${name}`);
  rmSync(tmp, { recursive: true, force: true });
  const browser = await chromium.launch();
  const context = await browser.newContext({
    // twice the pixels, captured straight from Chrome (Playwright's own video is 1x and soft)
    viewport, deviceScaleFactor: 2, locale: 'ru-RU', isMobile: mobile, hasTouch: mobile,
  });
  await context.addInitScript(OVERLAY);
  const page = await context.newPage();
  mkdirSync(join(tmp, 'f'), { recursive: true });
  const frames = [];
  const cdp = await context.newCDPSession(page);
  cdp.on('Page.screencastFrame', ({ data, metadata, sessionId }) => {
    const file = join(tmp, 'f', `${String(frames.length).padStart(6, '0')}.jpg`);
    writeFileSync(file, Buffer.from(data, 'base64'));
    frames.push({ file, t: metadata.timestamp });
    cdp.send('Page.screencastFrameAck', { sessionId }).catch(() => undefined);
  });
  await cdp.send('Page.startScreencast', { format: 'jpeg', quality: 92, maxWidth: viewport.width * 2, maxHeight: viewport.height * 2, everyNthFrame: 1 });
  const t0 = Date.now() / 1000;
  const captions = [];
  const at = () => Date.now() / 1000 - t0;
  let cursor = { x: viewport.width / 2, y: viewport.height / 2 };

  const h = {
    page,
    say(text, holdMs = 0) { captions.push({ start: at(), text }); return holdMs ? page.waitForTimeout(holdMs) : undefined; },
    pause: (ms = 1500) => page.waitForTimeout(ms),
    async goto(path) { await page.goto(`${WEB}${path}`); await page.waitForLoadState('networkidle', { timeout: 4000 }).catch(() => undefined); await page.evaluate(([x, y]) => window.__demo?.move(x, y), [cursor.x, cursor.y]); await page.waitForTimeout(600); },
    async point(target, { ring = true, wait = 900 } = {}) {
      const loc = typeof target === 'string' ? page.locator(target).first() : target.first();
      await loc.scrollIntoViewIfNeeded().catch(() => undefined);
      await page.waitForTimeout(250);
      const b = await loc.boundingBox();
      if (!b) throw new Error(`not visible: ${target}`);
      cursor = { x: b.x + b.width / 2, y: b.y + b.height / 2 };
      await page.evaluate(([x, y]) => window.__demo.move(x, y), [cursor.x, cursor.y]);
      await page.waitForTimeout(750);
      if (ring) await page.evaluate((bb) => window.__demo.ring(bb), b);
      await page.waitForTimeout(wait);
      return loc;
    },
    async click(target, opts = {}) {
      const loc = await h.point(target, opts);
      await page.evaluate(() => window.__demo.press(true));
      await page.waitForTimeout(120);
      await page.evaluate(() => { window.__demo.press(false); window.__demo.ring(null); });
      await loc.click();
      await page.waitForLoadState('networkidle', { timeout: 4000 }).catch(() => undefined);
      await page.waitForTimeout(opts.after ?? 1100);
    },
    async type(target, text, opts = {}) {
      const loc = await h.point(target, { ...opts, wait: 400 });
      await page.evaluate(() => window.__demo.ring(null));
      await loc.click();
      if (opts.clear !== false) await loc.fill('');
      else await loc.press('End');
      await loc.pressSequentially(text, { delay: 70 });
      await page.waitForTimeout(opts.after ?? 600);
    },
    /** a <select>: point at it, then choose the option by its visible text */
    async select(target, label, opts = {}) {
      const loc = await h.point(target, { ...opts, wait: 600 });
      await page.evaluate(() => window.__demo.ring(null));
      await loc.selectOption({ label });
      await page.waitForTimeout(opts.after ?? 900);
    },
    /** a <select> whose option text only starts with `prefix` */
    async selectStarting(target, prefix, opts = {}) {
      const loc = typeof target === 'string' ? page.locator(target).first() : target.first();
      const label = await loc.locator('option').evaluateAll((os, p) => os.map((o) => o.textContent).find((t) => t && t.startsWith(p)), prefix);
      return h.select(target, label, opts);
    },
    unring: () => page.evaluate(() => window.__demo.ring(null)),
    async scroll(dy) { await page.mouse.wheel(0, dy); await page.waitForTimeout(900); },
  };

  try {
    await script(h);
    await page.waitForTimeout(1500);
  } finally {
    captions.push({ start: at(), text: null });
    await cdp.send('Page.stopScreencast').catch(() => undefined);
    await context.close();
    await browser.close();
  }
  // frames come only when something changes: each one lasts until the next (the concat demuxer), from t0 on
  const fwd = (p) => p.split('\\').join('/');
  const lines = [];
  let prev = t0;
  const endAll = t0 + captions[captions.length - 1].start;
  frames.forEach((f, i) => {
    const end = i + 1 < frames.length ? frames[i + 1].t : endAll;
    lines.push(`file '${fwd(f.file)}'`, `duration ${Math.max(0.001, end - prev).toFixed(4)}`);
    prev = end;
  });
  lines.push(`file '${fwd(frames[frames.length - 1].file)}'`);
  const list = join(tmp, 'frames.txt');
  writeFileSync(list, lines.join('\n'));
  const size = { width: viewport.width * 2, height: viewport.height * 2 };
  for (const lang of LANGS) render(['-f', 'concat', '-safe', '0', '-i', list], captions, lang, join(OUT, `${name}-${lang}.mp4`), size);
  return captions;
}

// ---- captions -> ASS -> burnt into an H.264 MP4 ----------------------------------------------------------------------------
const ts = (s) => {
  const cs = Math.max(0, Math.round(s * 100));
  const h = Math.floor(cs / 360000), m = Math.floor((cs % 360000) / 6000), sec = Math.floor((cs % 6000) / 100), c = cs % 100;
  return `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}.${String(c).padStart(2, '0')}`;
};
const esc = (t) => t.replace(/\\/g, '\\\\').replace(/\{/g, '(').replace(/\}/g, ')').replace(/\n/g, '\\N');

/** the caption band under the picture (captions never cover the screen) */
export const band = ({ width, height }) => Math.round((width < height ? height * 0.13 : height * 0.16) / 2) * 2;

export function assFor(captions, lang, { width, height: screenH }) {
  const height = screenH + band({ width, height: screenH });
  // big and easy to read: a phone video gets relatively larger letters than a wide one
  const size = Math.round(width < screenH ? width / 15 : screenH / 18);
  const lines = [];
  for (let i = 0; i < captions.length - 1; i++) {
    const c = captions[i];
    if (!c.text) continue;
    const text = typeof c.text === 'string' ? c.text : c.text[lang];
    if (!text) continue;
    const y = screenH + (height - screenH) / 2;
    lines.push(`Dialogue: 0,${ts(c.start)},${ts(captions[i + 1].start)},Cap,,0,0,0,,{\\an5\\pos(${width / 2},${y})}${esc(text)}`);
  }
  return `[Script Info]
ScriptType: v4.00+
PlayResX: ${width}
PlayResY: ${height}
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Cap,Arial,${size},&H00FFFFFF,&H00FFFFFF,&H004F32A3,&H004F32A3,1,0,0,0,100,100,0,0,1,0,0,5,${Math.round(width / 24)},${Math.round(width / 24)},0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
${lines.join('\n')}
`;
}

export function render(input, captions, lang, output, size) {
  const dir = resolve(output, '..');
  const ass = join(dir, `.${lang}-${Date.now()}.ass`);
  writeFileSync(ass, assFor(captions, lang, size), 'utf8');
  // the filter path: relative, forward slashes, no drive colon (ffmpeg filter syntax)
  const rel = ass.replace(/\\/g, '/').replace(`${process.cwd().replace(/\\/g, '/')}/`, '');
  const r = spawnSync(ffmpegPath, [
    '-y', '-loglevel', 'error', ...(Array.isArray(input) ? input : ['-i', input]),
    '-vf', `scale=${size.width}:${size.height}:force_original_aspect_ratio=decrease,pad=${size.width}:${size.height}:(ow-iw)/2:(oh-ih)/2:color=0xFAF6F3,pad=${size.width}:${size.height + band(size)}:0:0:color=0xA3324F,ass='${rel}',format=yuv420p`, '-fps_mode', 'cfr',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '24', '-r', '25', '-movflags', '+faststart', '-an', output,
  ], { stdio: 'inherit' });
  rmSync(ass, { force: true });
  if (r.status !== 0) throw new Error(`ffmpeg failed for ${output}`);
  console.log(`  ✓ ${output}`);
}

/** staff login on the panel's login page, shown in the video */
export async function staffLogin(h, phoneDigits, { show = true } = {}) {
  await h.goto('/login');
  if (show) {
    await h.type(h.page.getByLabel('Телефон'), `+998 ${phoneDigits}`);
    await h.type(h.page.getByLabel('Пароль'), 'Demo-12345');
    await h.click(h.page.getByRole('button', { name: 'Войти' }), { after: 2500 });
  } else {
    await h.page.getByLabel('Телефон').fill(`+998${phoneDigits.replace(/\s/g, '')}`);
    await h.page.getByLabel('Пароль').fill('Demo-12345');
    await h.page.getByRole('button', { name: 'Войти' }).click();
    await h.page.waitForURL(/dashboard/);
  }
}
