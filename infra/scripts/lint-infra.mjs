#!/usr/bin/env node
/**
 * Static guardrails for the NAS deployment files (no Docker needed; run in CI and before every deploy).   pnpm infra:lint
 * Encodes the NAS-first rules of docs/DECISIONS.md so a careless edit cannot silently break them.
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from 'yaml';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const read = (p) => readFileSync(resolve(root, p), 'utf8');
const errors = [];
const fail = (m) => errors.push(m);

const composeText = read('docker-compose.yml');
const compose = parse(composeText, { merge: true }); // resolves `<<: *hardened`
const envVars = new Set([...read('.env.example').matchAll(/^#?\s*([A-Z][A-Z0-9_]*)=/gm)].map((m) => m[1]));
const services = compose.services ?? {};
const names = Object.keys(services);

// 1. variables used are documented or defaulted
const used = [...composeText.matchAll(/\$\{([A-Z][A-Z0-9_]*)(:[-?][^}]*)?\}/g)];
for (const [, v, mod] of used) if (!envVars.has(v) && !(mod && mod.startsWith(':-'))) fail(`compose uses \${${v}}: not in .env.example and no default`);

// 2. depends_on targets exist
for (const [n, s] of Object.entries(services)) for (const d of Array.isArray(s.depends_on) ? s.depends_on : Object.keys(s.depends_on ?? {})) if (!names.includes(d)) fail(`${n}: depends_on unknown service "${d}"`);

// 3. pinned images
for (const [n, s] of Object.entries(services)) {
  if (s.build || !s.image) { if (!s.build && !s.image) fail(`${n}: no image`); continue; }
  const img = String(s.image);
  const bare = img.replace(/^\$\{[^}]*:-/, '').replace(/\}$/, '');
  if (/:latest$/.test(bare) || !/[:@]/.test(bare)) fail(`${n}: image "${img}" is not pinned`);
}

// 4. nothing sensitive is published; console-style UIs only on 127.0.0.1; Caddy publishes ONE plain-HTTP port and never 80/443
//    (the NAS owns 80/443: D-025)
const NEVER = ['postgres', 'redis', 'api', 'worker', 'web', 'backup', 'migrate', 'minio-init', 'cloudflared'];
for (const [n, s] of Object.entries(services)) {
  const ports = (s.ports ?? []).map(String);
  if (NEVER.includes(n) && ports.length) fail(`${n}: must not publish ports (${ports.join(', ')})`);
  if (n === 'minio') for (const p of ports) if (!p.startsWith('127.0.0.1:')) fail(`minio: port "${p}" must be bound to 127.0.0.1`);
  if (n === 'caddy') {
    if (ports.length !== 1) fail(`caddy: must publish exactly one port (got ${ports.length})`);
    for (const p of ports) if (!/^\$\{HTTP_BIND:-127\.0\.0\.1\}:\$\{HTTP_PORT:-\d{4,5}\}:8080$/.test(p)) fail(`caddy: unexpected published port "${p}" (want \${HTTP_BIND:-127.0.0.1}:\${HTTP_PORT:-8088}:8080; 80/443 belong to the NAS)`);
  }
}

// 5. network isolation
if (compose.networks?.data?.internal !== true) fail('network "data" must be internal: true');
for (const st of ['postgres', 'redis', 'minio']) {
  const nets = Array.isArray(services[st]?.networks) ? services[st].networks : Object.keys(services[st]?.networks ?? {});
  if (nets.some((x) => x !== 'data')) fail(`${st}: must be on the internal "data" network only (got ${nets})`);
}
if (services.api?.networks && (Array.isArray(services.api.networks) ? services.api.networks : Object.keys(services.api.networks)).includes('egress')) fail('api: must not be on the egress network (only the worker talks to Telegram)');

// 5b. fixed subnets (shared NAS with many Docker projects); the tunnel is opt-in, pinned by default, edge network only
for (const net of ['edge', 'data', 'egress']) if (!compose.networks?.[net]?.ipam?.config?.[0]?.subnet) fail(`network "${net}": pin a subnet (ipam) — the NAS runs many other Docker networks`);
const tunnel = services.cloudflared;
if (tunnel) {
  if (!(tunnel.profiles ?? []).includes('tunnel')) fail('cloudflared must be opt-in (profile "tunnel")');
  const nets = Array.isArray(tunnel.networks) ? tunnel.networks : Object.keys(tunnel.networks ?? {});
  if (nets.length !== 1 || nets[0] !== 'edge') fail(`cloudflared: must be on the edge network only (got ${nets})`);
  if (!/^\$\{TUNNEL|^\$\{CLOUDFLARE_TUNNEL_TOKEN/.test(String(tunnel.environment?.TUNNEL_TOKEN ?? ''))) fail('cloudflared: the tunnel token must come from .env');
}

// 6. configurable host paths
for (const [n, s] of Object.entries(services)) for (const v of s.volumes ?? []) {
  const src = String(v).split(':')[0];
  if (src.startsWith('/') && !src.startsWith('${')) fail(`${n}: hard-coded host path "${src}" — use DATA_ROOT/BACKUP_ROOT`);
  if (src.startsWith('./') && !existsSync(resolve(root, src))) fail(`${n}: volume source "${src}" does not exist`);
}

// 7. operations hygiene
for (const [n, s] of Object.entries(services)) {
  const oneShot = s.restart === 'no';
  if (!oneShot && !s.healthcheck) fail(`${n}: no healthcheck`);
  if (!oneShot && s.restart !== 'unless-stopped') fail(`${n}: restart policy should be unless-stopped`);
  if (!s.logging) fail(`${n}: no log rotation`);
  if (!oneShot && !s.mem_limit) fail(`${n}: no mem_limit`);
}

// 8. hardened app containers
for (const n of ['api', 'worker', 'web']) {
  const s = services[n];
  if (!s) continue;
  if (s.read_only !== true) fail(`${n}: read_only root filesystem expected`);
  if (!(s.cap_drop ?? []).includes('ALL')) fail(`${n}: cap_drop ALL expected`);
}

// 9. required services (brief §54)
for (const r of ['postgres', 'redis', 'minio', 'api', 'web', 'worker', 'caddy', 'backup']) if (!services[r]) fail(`missing service "${r}"`);

// 10. Caddy file
for (const f of ['infra/caddy/Caddyfile']) {
  const t = read(f);
  if (!/^:8080\s*\{/m.test(t)) fail(`${f}: must listen on plain :8080 (TLS is the tunnel's job, D-025)`);
  if (!/auto_https off/.test(t)) fail(`${f}: auto_https off expected (the NAS owns 80/443)`);
  if (!/trusted_proxies/.test(t)) fail(`${f}: trusted_proxies expected so the API sees real client IPs`);
  for (const [, v] of t.matchAll(/\{\$([A-Z0-9_]+)/g)) if (!envVars.has(v)) fail(`${f}: {$${v}} not in .env.example`);
  if (!/respond @internal 404/.test(t)) fail(`${f}: must block /health/ready and Swagger`);
  if (/minio|postgres|redis/i.test(t.replace(/^\s*#.*$/gm, ''))) fail(`${f}: must never route to minio/postgres/redis`);
  if (!/socket\.io/.test(t)) fail(`${f}: /socket.io must be proxied (realtime)`);
}

// 11. secrets
for (const f of ['.env.example', 'docker-compose.yml']) if (/(password|secret|token)\s*[:=]\s*(?!CHANGE_ME|\$|["']?\s*$)[A-Za-z0-9+/:_-]{24,}/i.test(read(f).replace(/^\s*#.*$/gm, ''))) fail(`${f}: looks like a real secret is committed`);
if (!/^\.env$/m.test(read('.gitignore'))) fail('.gitignore must ignore .env');
if (!existsSync(resolve(root, '.dockerignore'))) fail('.dockerignore is missing: the build context would contain .env and node_modules');
else {
  const di = read('.dockerignore');
  if (!/^\.env$/m.test(di)) fail('.dockerignore must exclude .env (secrets must never enter a build context)');
  if (!/node_modules/.test(di)) fail('.dockerignore must exclude node_modules');
}

// 12. MinIO buckets in init script == buckets known to the app
const shared = read('packages/shared/src/basics.ts');
const appBuckets = /FILE_BUCKETS = \[([^\]]+)\]/.exec(shared)?.[1].match(/'([a-z]+)'/g)?.map((s) => s.replace(/'/g, '')).sort().join(' ');
const initBuckets = /BUCKETS="([^"]+)"/.exec(read('infra/minio/minio-init.sh'))?.[1].split(/\s+/).sort().join(' ');
if (appBuckets !== initBuckets) fail(`bucket lists differ: app [${appBuckets}] vs minio-init [${initBuckets}]`);

if (errors.length) {
  console.error(`infra lint FAILED (${errors.length}):`);
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}
console.log(`infra lint OK — ${names.length} services, ${used.length} variable references checked`);
