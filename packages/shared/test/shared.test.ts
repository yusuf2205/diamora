import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  ADMIN_GRANTABLE,
  ASSIGNMENT_MACHINE,
  ASSIGNMENT_STATUSES,
  COLLATERAL_MACHINE,
  EVENT_ROUTES,
  INITIAL_PAY_RATE_UZS,
  InvalidTransitionError,
  MANAGER_GRANTABLE,
  MAX_PAY_RATE_UZS,
  MAX_PHOTOS,
  PERMISSIONS,
  ROLE_DEFAULT_PERMISSIONS,
  ROLE_RANK,
  SUPER_ADMIN_ONLY,
  advance,
  catAllRoom,
  catManagerRoom,
  changePayRateSchema,
  assertTransition,
  canTransition,
  divRoundHalfUp,
  earningFor,
  effectivePermissions,
  initialRegState,
  isStaffRole,
  isTerminal,
  metersToCm,
  normalizePhone,
  parseQrCode,
  parseUzs,
  roomsForEvent,
  roomsForUser,
  scopeFor,
  workerRoom,
  type RegInput,
  type RegState,
} from '../src';

const me = 777;
const run = (inputs: RegInput[], from: RegState = initialRegState()) => {
  let state = from;
  let last = advance(state, inputs[0]);
  state = last.state;
  for (const i of inputs.slice(1)) {
    last = advance(state, i);
    state = last.state;
  }
  return last;
};
const text = (t: string): RegInput => ({ kind: 'text', text: t });
const action = (a: Extract<RegInput, { kind: 'action' }>['action']): RegInput => ({ kind: 'action', action: a });
const contact: RegInput = { kind: 'contact', phone: '998901234567', contactUserId: me, senderUserId: me };
const loc: RegInput = { kind: 'location', latitude: 41.2995, longitude: 69.2401 };

describe('phone / money / qr', () => {
  test('normalizePhone handles Telegram contact and local notations', () => {
    assert.equal(normalizePhone('998901234567'), '+998901234567');
    assert.equal(normalizePhone('+998 90 123-45-67'), '+998901234567');
    assert.equal(normalizePhone('90 123 45 67'), '+998901234567');
    assert.equal(normalizePhone('abc'), null);
    assert.equal(normalizePhone('+99890123'), null);
  });
  test('money: parse, rounding, earning is priced per 9 m kit (D-024)', () => {
    assert.equal(parseUzs('1 500 000'), 1_500_000n);
    assert.throws(() => parseUzs('12.5'));
    assert.equal(divRoundHalfUp(5n, 2n), 3n);
    assert.equal(earningFor(450_000n, 900), 450_000n); // one kit = the rate itself
    assert.equal(earningFor(450_000n, 1800), 900_000n); // 18 m = 2 kits
    assert.equal(earningFor(450_000n, 2700), 1_350_000n); // 27 m = 3 kits
    assert.equal(earningFor(450_000n, 650), 325_000n); // 6.5 m of a kit, pro rata
    assert.equal(earningFor(1_001n, 450), 501n); // half a kit: 500.5 rounds up
    assert.equal(earningFor(450_000n, 0), 0n);
    assert.throws(() => earningFor(450_000n, 1.5));
    assert.equal(metersToCm(6.5), 650);
    assert.throws(() => metersToCm(1.234));
  });
  test('global 9 m price (D-027): starts at 30 000, ADMIN input is validated, the broadcast reaches every worker', () => {
    assert.equal(INITIAL_PAY_RATE_UZS, 30_000n);
    assert.equal(earningFor(INITIAL_PAY_RATE_UZS, 900), 30_000n);
    assert.equal(earningFor(INITIAL_PAY_RATE_UZS, 2700), 90_000n);
    assert.equal(changePayRateSchema.parse({ ratePerKit: '35000' }).ratePerKit, 35_000n);
    assert.equal(changePayRateSchema.parse({ ratePerKit: 30000, note: '  Индексация ' }).note, 'Индексация');
    assert.equal(changePayRateSchema.parse({ ratePerKit: MAX_PAY_RATE_UZS.toString() }).ratePerKit, MAX_PAY_RATE_UZS);
    for (const bad of [0, -1, 1.5, '12.5', 'abc', '', '10000001', null, undefined]) assert.equal(changePayRateSchema.safeParse({ ratePerKit: bad }).success, false, `must reject ${String(bad)}`);
    assert.deepEqual(EVENT_ROUTES['pay_rate.changed'], { staff: true, allWorkers: true });
  });
  test('QR code: only our opaque format is accepted', () => {
    assert.equal(parseQrCode(' yq1.k7m2qx9tpd4r '), 'YQ1.K7M2QX9TPD4R');
    assert.equal(parseQrCode('https://evil.example/x'), null);
    assert.equal(parseQrCode('YQ1.SHORT'), null);
    assert.equal(parseQrCode('YQ1.ILOU0000000A'), null); // excluded letters
  });
});

describe('Telegram registration state machine', () => {
  test('happy path with MONEY collateral reaches SUBMITTED', () => {
    const r = run([text('Малика Каримова'), contact, action('skip'), loc, action('type_money'), text('1 500 000'), action('skip'), action('confirm')]);
    assert.equal(r.submit, true);
    assert.equal(r.prompt, 'SUBMITTED');
    assert.deepEqual(
      { ...r.state.data },
      {
        fullName: 'Малика Каримова',
        phone: '+998901234567',
        secondaryPhone: null,
        latitude: 41.2995,
        longitude: 69.2401,
        collateralType: 'MONEY',
        collateralAmount: '1500000',
        photoCount: 0,
        note: null,
      },
    );
  });

  test('ITEM collateral needs a description and at least one photo; photos are counted and limited', () => {
    let r = run([text('Гуля Юсупова'), contact, text('+998 91 111 22 33'), loc, action('type_item'), text('Золотое кольцо 585')]);
    assert.equal(r.prompt, 'ASK_PHOTOS');
    r = advance(r.state, action('photos_done'));
    assert.equal(r.error, 'PHOTO_REQUIRED');
    r = advance(r.state, { kind: 'photo' });
    assert.equal(r.acceptPhoto, true);
    let st = r.state;
    for (let i = 1; i < MAX_PHOTOS; i++) st = advance(st, { kind: 'photo' }).state;
    assert.equal(advance(st, { kind: 'photo' }).error, 'PHOTO_LIMIT');
    assert.equal(advance(st, { kind: 'photo' }).acceptPhoto, undefined);
    r = advance(st, action('photos_done'));
    assert.equal(r.prompt, 'ASK_NOTE');
    r = advance(r.state, text('Кольцо с камнем'));
    assert.equal(r.prompt, 'CONFIRM');
    assert.equal(r.state.data.secondaryPhone, '+998911112233');
    assert.equal(advance(r.state, action('confirm')).submit, true);
  });

  test('a contact that is not the sender own number is rejected (no forwarded contacts)', () => {
    const r = run([text('Малика'), { kind: 'contact', phone: '998901112233', contactUserId: 5, senderUserId: me }]);
    assert.equal(r.error, 'PHONE_NOT_OWN');
    assert.equal(r.prompt, 'ASK_PHONE');
    assert.equal(advance(r.state, { kind: 'contact', phone: '998901112233', contactUserId: null, senderUserId: me }).error, 'PHONE_NOT_OWN');
  });

  test('validation errors keep the same step', () => {
    let r = advance(initialRegState(), text('1'));
    assert.equal(r.error, 'NAME_INVALID');
    r = advance(initialRegState(), loc);
    assert.equal(r.error, 'UNEXPECTED_INPUT');
    const atLoc = run([text('Малика'), contact, action('skip')]).state;
    assert.equal(advance(atLoc, { kind: 'location', latitude: 123, longitude: 0 }).error, 'LOCATION_INVALID');
    const atAmount = run([text('Малика'), contact, action('skip'), loc, action('type_money')]).state;
    for (const bad of ['0', '-5', '12.5', 'abc', '']) assert.equal(advance(atAmount, text(bad)).error, 'AMOUNT_INVALID', bad);
  });

  test('editing from the confirmation screen returns to it and changing collateral type resets photos', () => {
    let r = run([text('Малика'), contact, action('skip'), loc, action('type_item'), text('Кольцо'), { kind: 'photo' }, action('photos_done'), action('skip')]);
    assert.equal(r.prompt, 'CONFIRM');
    r = advance(r.state, action('edit'));
    assert.equal(r.prompt, 'EDIT_MENU');
    r = advance(r.state, action('edit_name'));
    assert.equal(r.prompt, 'ASK_NAME');
    r = advance(r.state, text('Малика Исправленная'));
    assert.equal(r.prompt, 'CONFIRM');
    assert.equal(r.state.data.fullName, 'Малика Исправленная');
    // switch collateral to money
    r = advance(advance(r.state, action('edit')).state, action('edit_collateral'));
    r = advance(r.state, action('type_money'));
    assert.equal(r.resetPhotos, true);
    assert.equal(r.state.data.photoCount, 0);
    r = advance(r.state, text('500000'));
    assert.equal(r.prompt, 'CONFIRM');
    assert.equal(advance(r.state, action('confirm')).submit, true);
  });

  test('cannot confirm an incomplete registration; SUBMITTED is final', () => {
    const st: RegState = { step: 'CONFIRM', data: { photoCount: 0, fullName: 'X Y' }, returnToConfirm: false };
    assert.equal(advance(st, action('confirm')).error, 'INCOMPLETE');
    const done = run([text('Малика'), contact, action('skip'), loc, action('type_money'), text('100000'), action('skip'), action('confirm')]);
    assert.equal(advance(done.state, text('again')).prompt, 'SUBMITTED');
    assert.equal(advance(done.state, text('again')).submit, undefined);
  });

  test('the machine never mutates the previous state (safe to persist only on success)', () => {
    const before = initialRegState();
    const snapshot = JSON.stringify(before);
    advance(before, text('Малика'));
    assert.equal(JSON.stringify(before), snapshot);
  });
});

describe('state machines', () => {
  test('assignment: reachable from DRAFT, terminals are COMPLETED/CANCELLED', () => {
    const seen = new Set<string>(['DRAFT']);
    const q = ['DRAFT'];
    while (q.length) {
      const s = q.shift() as (typeof ASSIGNMENT_STATUSES)[number];
      for (const e of ASSIGNMENT_MACHINE[s]) if (!seen.has(e.to)) (seen.add(e.to), q.push(e.to));
    }
    for (const s of ASSIGNMENT_STATUSES) assert.ok(seen.has(s), `${s} unreachable`);
    assert.deepEqual(ASSIGNMENT_STATUSES.filter((s) => isTerminal(ASSIGNMENT_MACHINE, s)).sort(), ['CANCELLED', 'COMPLETED']);
  });
  test('assignment: no arbitrary jumps; workers only do their own steps', () => {
    assert.throws(() => assertTransition('A', ASSIGNMENT_MACHINE, 'DRAFT', 'COMPLETED', 'ADMIN'), InvalidTransitionError);
    assert.throws(() => assertTransition('A', ASSIGNMENT_MACHINE, 'UNDER_REVIEW', 'ACCEPTED', 'WORKER'), InvalidTransitionError);
    assert.equal(canTransition(ASSIGNMENT_MACHINE, 'IN_PROGRESS', 'READY_FOR_PICKUP', 'WORKER'), true);
    assert.equal(canTransition(ASSIGNMENT_MACHINE, 'READY_FOR_PICKUP', 'PICKED_UP', 'WORKER'), false);
    assert.equal(canTransition(ASSIGNMENT_MACHINE, 'DELIVERED', 'IN_PROGRESS', 'ADMIN'), true);
  });
  test('collateral: PENDING → HELD → RETURNED only, by ADMIN', () => {
    assert.equal(canTransition(COLLATERAL_MACHINE, 'PENDING', 'HELD', 'ADMIN'), true);
    assert.equal(canTransition(COLLATERAL_MACHINE, 'PENDING', 'RETURNED', 'ADMIN'), false);
    assert.equal(canTransition(COLLATERAL_MACHINE, 'HELD', 'RETURNED', 'WORKER'), false);
    assert.equal(isTerminal(COLLATERAL_MACHINE, 'RETURNED'), true);
  });
  test('every realtime event routes somewhere (staff, a worker category, or a broadcast)', () => {
    for (const [type, r] of Object.entries(EVENT_ROUTES)) {
      assert.ok(r.perms?.length || r.cat || r.worker || r.allWorkers || r.staff || r.user, type);
    }
  });
});

describe('RBAC (D-028): roles, permissions, manager scope, realtime rooms', () => {
  test('rank: SUPER_ADMIN > ADMIN > MANAGER > WORKER, strictly decreasing', () => {
    assert.deepEqual(ROLE_RANK, { SUPER_ADMIN: 4, ADMIN: 3, MANAGER: 2, WORKER: 1 });
    assert.deepEqual([...new Set(Object.values(ROLE_RANK))].sort((a, b) => a - b), [1, 2, 3, 4]);
    assert.equal(isStaffRole('SUPER_ADMIN'), true);
    assert.equal(isStaffRole('MANAGER'), true);
    assert.equal(isStaffRole('WORKER'), false);
  });

  test('SUPER_ADMIN has every permission; WORKER has none; ADMIN/MANAGER defaults are disjoint from each other\'s exclusives', () => {
    assert.deepEqual(effectivePermissions('SUPER_ADMIN'), PERMISSIONS);
    assert.deepEqual(effectivePermissions('WORKER'), []);
    assert.deepEqual(effectivePermissions('WORKER', [{ permission: 'PAY_RATE_MANAGE', granted: true }]), []); // fixed set: overrides ignored
    assert.ok(ROLE_DEFAULT_PERMISSIONS.ADMIN.includes('WORKER_VIEW_ALL'));
    assert.ok(!ROLE_DEFAULT_PERMISSIONS.ADMIN.includes('PAY_RATE_MANAGE')); // §39: only "если permission разрешает"
    assert.ok(ROLE_DEFAULT_PERMISSIONS.MANAGER.includes('WORKER_VIEW_ASSIGNED'));
    assert.ok(!ROLE_DEFAULT_PERMISSIONS.MANAGER.includes('WORKER_VIEW_ALL'));
  });

  test('ROLE_ASSIGN / PERMISSION_MANAGE can never be granted to anyone but SUPER_ADMIN', () => {
    assert.deepEqual(SUPER_ADMIN_ONLY, ['ROLE_ASSIGN', 'PERMISSION_MANAGE']);
    assert.ok(!ADMIN_GRANTABLE.includes('ROLE_ASSIGN') && !ADMIN_GRANTABLE.includes('PERMISSION_MANAGE'));
    assert.ok(!MANAGER_GRANTABLE.includes('ROLE_ASSIGN') && !MANAGER_GRANTABLE.includes('PERMISSION_MANAGE'));
    // a MANAGER is never grantable an _ALL (global) permission, only the _ASSIGNED ones come by default
    assert.ok(!MANAGER_GRANTABLE.some((p) => p.endsWith('_ALL')));
  });

  test('effectivePermissions: grant adds, revoke removes, an override outside what the role may hold is ignored', () => {
    const granted = effectivePermissions('ADMIN', [{ permission: 'PAY_RATE_MANAGE', granted: true }]);
    assert.ok(granted.includes('PAY_RATE_MANAGE') && granted.includes('WORKER_VIEW_ALL'));
    const revoked = effectivePermissions('ADMIN', [{ permission: 'WORKER_VIEW_ALL', granted: false }]);
    assert.ok(!revoked.includes('WORKER_VIEW_ALL'));
    const ignored = effectivePermissions('MANAGER', [{ permission: 'PAY_RATE_MANAGE', granted: true }]); // not MANAGER_GRANTABLE
    assert.ok(!ignored.includes('PAY_RATE_MANAGE'));
  });

  test('scopeFor: _ALL beats _ASSIGNED, missing both is "none"', () => {
    assert.equal(scopeFor(['WORKER_VIEW_ALL'], 'WORKER'), 'all');
    assert.equal(scopeFor(['WORKER_VIEW_ASSIGNED'], 'WORKER'), 'assigned');
    assert.equal(scopeFor([], 'WORKER'), 'none');
    // COLLATERAL needs WORKER_VIEW_ASSIGNED *and* COLLATERAL_VIEW together for 'assigned'
    assert.equal(scopeFor(['WORKER_VIEW_ASSIGNED'], 'COLLATERAL'), 'none');
    assert.equal(scopeFor(['WORKER_VIEW_ASSIGNED', 'COLLATERAL_VIEW'], 'COLLATERAL'), 'assigned');
  });

  test('roomsForUser: a MANAGER only ever joins her own manager-scoped rooms, never a blanket "all" room', () => {
    const manager = { id: 'mgr-1', role: 'MANAGER' as const, workerId: null, permissions: effectivePermissions('MANAGER') };
    const rooms = roomsForUser(manager);
    assert.ok(rooms.includes(catManagerRoom('WORKER', 'mgr-1')));
    assert.ok(!rooms.includes(catAllRoom('WORKER')));
    assert.ok(rooms.includes('staff'));
    const worker = { id: 'u-1', role: 'WORKER' as const, workerId: 'w-1', permissions: [] };
    assert.deepEqual(roomsForUser(worker).sort(), ['user:u-1', 'worker:w-1', 'workers'].sort());
  });

  test('roomsForEvent: a manager-scoped event reaches the current AND the previous manager, never a bystander', () => {
    const rooms = roomsForEvent('worker.manager_changed', { workerId: 'w-1', managerId: 'mgr-a', previousManagerId: 'mgr-b' });
    assert.ok(rooms.includes(catManagerRoom('WORKER', 'mgr-a')));
    assert.ok(rooms.includes(catManagerRoom('WORKER', 'mgr-b')));
    assert.ok(!rooms.includes(catManagerRoom('WORKER', 'mgr-c')));
    assert.ok(rooms.includes(catAllRoom('WORKER')));
  });

  test('roomsForEvent: pay_rate.changed reaches staff and every worker; worker.approved also reaches that one worker', () => {
    assert.deepEqual(roomsForEvent('pay_rate.changed', {}).sort(), ['staff', 'workers'].sort());
    const rooms = roomsForEvent('worker.approved', { workerId: 'w-9', managerId: null });
    assert.ok(rooms.includes(workerRoom('w-9')));
    assert.ok(rooms.includes(catAllRoom('WORKER')));
  });
});
