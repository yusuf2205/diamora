import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { readdir, readFile, rm, mkdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

/**
 * Yandex Cloud for the chat (owner, 2026-10-11): «голосовое → текст» (SpeechKit) and «перевод узбекский ↔ русский»
 * (Translate). Off until YANDEX_CLOUD_API_KEY and YANDEX_CLOUD_FOLDER_ID are set in .env (an API key of a service account
 * with the roles ai.speechkit-stt.user and ai.translate.user).
 */
export type AiLang = 'ru' | 'uz';
const STT_LANG: Record<AiLang, string> = { ru: 'ru-RU', uz: 'uz-UZ' };

export class AiNotConfigured extends Error {}

export function aiConfig() {
  const key = process.env.YANDEX_CLOUD_API_KEY?.trim();
  const folder = process.env.YANDEX_CLOUD_FOLDER_ID?.trim();
  return key && folder ? { key, folder } : null;
}

function run(cmd: string, args: string[], timeoutMs: number): Promise<boolean> {
  return new Promise((resolve) => {
    const p = spawn(cmd, args, { stdio: 'ignore' });
    const t = setTimeout(() => { p.kill('SIGKILL'); resolve(false); }, timeoutMs);
    p.on('error', () => { clearTimeout(t); resolve(false); });
    p.on('close', (code) => { clearTimeout(t); resolve(code === 0); });
  });
}

/**
 * A voice note (AAC / anything ffmpeg reads) -> text. SpeechKit's quick recognition takes Ogg Opus up to 30 s, so the
 * voice is cut into 25 s Ogg pieces and their texts joined. At most 5 minutes.
 */
export async function speechToText(audio: Buffer, lang: AiLang, ffmpeg = process.env.FFMPEG_PATH ?? 'ffmpeg'): Promise<string> {
  const cfg = aiConfig();
  if (!cfg) throw new AiNotConfigured('Yandex Cloud is not configured');
  const dir = join(tmpdir(), `stt-${randomUUID()}`);
  await mkdir(dir, { recursive: true });
  try {
    const src = join(dir, 'in');
    await writeFile(src, audio);
    const ok = await run(ffmpeg, ['-v', 'error', '-y', '-i', src, '-t', '300', '-ac', '1', '-ar', '48000', '-c:a', 'libopus', '-b:a', '32k', '-f', 'segment', '-segment_time', '25', join(dir, 'part-%03d.ogg')], 60_000);
    if (!ok) throw new Error('Could not read the voice note');
    const parts = (await readdir(dir)).filter((f) => f.startsWith('part-')).sort();
    const texts: string[] = [];
    for (const part of parts) {
      const body = await readFile(join(dir, part));
      const res = await fetch(`https://stt.api.cloud.yandex.net/speech/v1/stt:recognize?lang=${STT_LANG[lang]}&folderId=${encodeURIComponent(cfg.folder)}&format=oggopus`, {
        method: 'POST', headers: { Authorization: `Api-Key ${cfg.key}` }, body, signal: AbortSignal.timeout(30_000),
      });
      if (!res.ok) throw new Error(`SpeechKit ${res.status}`);
      const j = (await res.json()) as { result?: string };
      if (j.result) texts.push(j.result.trim());
    }
    return texts.join(' ').trim();
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

/** Uzbek ↔ Russian (the source language is detected) */
export async function translate(text: string, to: AiLang): Promise<string> {
  const cfg = aiConfig();
  if (!cfg) throw new AiNotConfigured('Yandex Cloud is not configured');
  const res = await fetch('https://translate.api.cloud.yandex.net/translate/v2/translate', {
    method: 'POST',
    headers: { Authorization: `Api-Key ${cfg.key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ folderId: cfg.folder, texts: [text.slice(0, 4000)], targetLanguageCode: to }),
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) throw new Error(`Translate ${res.status}`);
  const j = (await res.json()) as { translations?: { text: string }[] };
  return j.translations?.[0]?.text ?? '';
}
