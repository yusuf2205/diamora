import assert from 'node:assert/strict';
import { test } from 'node:test';
import { step } from './logic.mjs';

const T = Date.parse('2026-10-01T05:00:00Z'); // 10:00 in Tashkent
const min = 60000;

test('one failed check stays quiet (a blip or a deploy restart)', () => {
  const r = step(null, { ok: false, failed: ['сайт'] }, T);
  assert.equal(r.message, null);
  assert.deepEqual(r.state, { fails: 1, since: T, alerted: false });
});

test('the second failure in a row tells the owner once; then quiet; back up -> «снова работает» with the down time', () => {
  let s = step(null, { ok: false, failed: ['сайт diamoraa.uz'] }, T).state;
  const down = step(s, { ok: false, failed: ['сайт diamoraa.uz'] }, T + 2 * min);
  assert.match(down.message, /не отвечает с 10:00/);
  assert.match(down.message, /сайт diamoraa\.uz/);
  s = down.state;
  const again = step(s, { ok: false, failed: ['сайт diamoraa.uz'] }, T + 4 * min);
  assert.equal(again.message, null);
  const up = step(again.state, { ok: true, failed: [] }, T + 34 * min);
  assert.match(up.message, /снова работает/);
  assert.match(up.message, /примерно 34 мин \(с 10:00 до 10:34\)/);
  assert.deepEqual(up.state, { fails: 0, since: null, alerted: false });
});

test('a single failure followed by success says nothing at all', () => {
  const s = step(null, { ok: false, failed: ['x'] }, T).state;
  const r = step(s, { ok: true, failed: [] }, T + 2 * min);
  assert.equal(r.message, null);
  assert.equal(r.state.fails, 0);
});

test('all fine: nothing to write, nothing to store', () => {
  const r = step({ fails: 0, since: null, alerted: false }, { ok: true, failed: [] }, T);
  assert.equal(r.changed, false);
});
