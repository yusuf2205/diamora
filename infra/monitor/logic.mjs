// Pure decision logic of the outside watchdog (no I/O): what to remember and whether to write to the owner.
// A check fails -> count it; the SECOND failure in a row (~4 min, so a short blip or a deploy restart stays quiet) sends
// «не отвечает»; the first success after that sends «снова работает, было недоступно N мин».

export const FAILS_TO_ALERT = 2;

const hhmm = (ms) => new Date(ms).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Tashkent' });
const span = (ms) => {
  const m = Math.max(1, Math.round(ms / 60000));
  return m < 60 ? `${m} мин` : `${Math.floor(m / 60)} ч ${m % 60} мин`;
};

/**
 * @param {{fails:number, since:number|null, alerted:boolean}} state
 * @param {{ok:boolean, failed:string[]}} check  failed = names of what did not answer
 * @param {number} now ms
 * @returns {{state: {fails:number, since:number|null, alerted:boolean}, message: string|null, changed: boolean}}
 */
export function step(state, check, now) {
  const s = state ?? { fails: 0, since: null, alerted: false };
  if (check.ok) {
    if (s.fails === 0) return { state: s, message: null, changed: false };
    const message = s.alerted ? `🟢 Diamoraa снова работает.\nБыло недоступно примерно ${span(now - s.since)} (с ${hhmm(s.since)} до ${hhmm(now)}).` : null;
    return { state: { fails: 0, since: null, alerted: false }, message, changed: true };
  }
  const next = { fails: s.fails + 1, since: s.since ?? now, alerted: s.alerted };
  if (!s.alerted && next.fails >= FAILS_TO_ALERT) {
    next.alerted = true;
    return {
      state: next,
      changed: true,
      message: `🔴 Diamoraa не отвечает с ${hhmm(next.since)}.\nНе открывается: ${check.failed.join(', ')}.\n\nПроверьте NAS: включён ли он, есть ли интернет (роутер, кабель). Если NAS включён — перезагрузите роутер.`,
    };
  }
  return { state: next, message: null, changed: true };
}
