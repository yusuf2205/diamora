// Cloudflare Worker: the outside watchdog for Diamoraa. Runs every 2 minutes (wrangler.toml), even when the NAS is off,
// and writes to the owner's Telegram through the same bot. Secrets (never in git): TELEGRAM_BOT_TOKEN, CHAT_IDS.
import { step } from './logic.mjs';

const TARGETS = [
  ['сайт diamoraa.uz', 'https://diamoraa.uz/v1/health/live'],
  ['панель admin.diamoraa.uz', 'https://admin.diamoraa.uz/login'],
];

async function probe(url) {
  try {
    const res = await fetch(url, { method: 'GET', redirect: 'manual', signal: AbortSignal.timeout(15000), headers: { 'user-agent': 'diamoraa-watchdog' }, cf: { cacheTtl: 0 } });
    return res.status < 500; // 530 / 502 = the tunnel or the NAS is gone; a 3xx/4xx still means it answers
  } catch {
    return false;
  }
}

async function tell(env, text) {
  const chats = String(env.CHAT_IDS ?? '').split(',').map((c) => c.trim()).filter(Boolean);
  await Promise.all(chats.map((chat_id) => fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ chat_id, text }),
  })));
}

async function run(env) {
  const results = await Promise.all(TARGETS.map(async ([name, url]) => [name, await probe(url)]));
  const failed = results.filter(([, ok]) => !ok).map(([name]) => name);
  const before = await env.STATE.get('state', 'json');
  const r = step(before, { ok: failed.length === 0, failed }, Date.now());
  if (r.changed) await env.STATE.put('state', JSON.stringify(r.state));
  if (r.message) await tell(env, r.message);
  return { failed, ...r };
}

export default {
  async scheduled(_event, env, ctx) { ctx.waitUntil(run(env)); },
  // GET /  -> the current state (handy to check it is alive); nothing secret in it
  async fetch(_req, env) { return Response.json(await env.STATE.get('state', 'json') ?? { fails: 0, since: null, alerted: false }); },
};
