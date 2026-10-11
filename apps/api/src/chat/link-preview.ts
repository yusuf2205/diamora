import { lookup } from 'node:dns/promises';
import { isIP } from 'node:net';

export interface LinkPreview { url: string; title: string | null; description: string | null; image: string | null; site: string | null }

/** never our own network or the NAS: only public addresses (a link is a stranger's input) */
function privateAddress(ip: string): boolean {
  if (isIP(ip) === 6) {
    const l = ip.toLowerCase();
    return l === '::1' || l.startsWith('fc') || l.startsWith('fd') || l.startsWith('fe80') || l.startsWith('::ffff:127.') || l.startsWith('::ffff:10.') || l.startsWith('::ffff:192.168.');
  }
  const [a, b] = ip.split('.').map(Number);
  return a === 10 || a === 127 || a === 0 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127) || a >= 224;
}

const decode = (s: string) => s.replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/\s+/g, ' ').trim();

function meta(html: string, ...names: string[]): string | null {
  for (const n of names) {
    const re = new RegExp(`<meta[^>]+(?:property|name)=["']${n}["'][^>]*content=["']([^"']+)["']|<meta[^>]+content=["']([^"']+)["'][^>]*(?:property|name)=["']${n}["']`, 'i');
    const m = re.exec(html);
    const v = m?.[1] ?? m?.[2];
    if (v) return decode(v).slice(0, 300);
  }
  return null;
}

/**
 * A link's card like Telegram's: og:title / og:description / og:image of the page. Only http(s) to public addresses,
 * 5 s, the first 512 KB of HTML; nothing stored if the page gives nothing useful.
 */
export async function fetchLinkPreview(raw: string, timeoutMs = 5000): Promise<LinkPreview | null> {
  let url: URL;
  try { url = new URL(raw); } catch { return null; }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
  const addrs = await lookup(url.hostname, { all: true }).catch(() => []);
  if (!addrs.length || addrs.some((a) => privateAddress(a.address))) return null;
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, { signal: ctrl.signal, redirect: 'follow', headers: { 'User-Agent': 'Mozilla/5.0 (compatible; DiamoraaBot/1.0; +https://diamoraa.uz)', Accept: 'text/html' } });
    if (!res.ok || !(res.headers.get('content-type') ?? '').includes('text/html') || !res.body) return null;
    // the final address after redirects must be public too
    const final = new URL(res.url);
    const finalAddrs = await lookup(final.hostname, { all: true }).catch(() => []);
    if (finalAddrs.some((a) => privateAddress(a.address))) return null;
    const reader = res.body.getReader();
    const chunks: Uint8Array[] = [];
    let size = 0;
    while (size < 512 * 1024) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
      size += value.length;
    }
    await reader.cancel().catch(() => undefined);
    const html = Buffer.concat(chunks).toString('utf8');
    const title = meta(html, 'og:title', 'twitter:title') ?? (/<title[^>]*>([^<]{1,300})<\/title>/i.exec(html)?.[1] ? decode(/<title[^>]*>([^<]{1,300})<\/title>/i.exec(html)![1]) : null);
    const description = meta(html, 'og:description', 'twitter:description', 'description');
    let image = meta(html, 'og:image', 'twitter:image');
    if (image) { try { image = new URL(image, final).toString(); } catch { image = null; } }
    if (image && !image.startsWith('https://')) image = null;
    const site = meta(html, 'og:site_name') ?? final.hostname.replace(/^www\./, '');
    if (!title && !description) return null;
    return { url: final.toString(), title, description: description?.slice(0, 300) ?? null, image, site };
  } catch {
    return null;
  } finally {
    clearTimeout(t);
  }
}
