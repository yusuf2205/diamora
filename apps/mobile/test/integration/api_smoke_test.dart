// Smoke test of the REAL client code against a RUNNING API (Flutter -> NestJS -> PostgreSQL). Skipped unless configured:
//   flutter test test/integration/api_smoke_test.dart --dart-define=API_URL=http://127.0.0.1:3055 \
//     --dart-define=SMOKE_ADMIN_PHONE=+998901112233 --dart-define=SMOKE_ADMIN_PASSWORD=...
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yusmus_mobile/core/db/app_database.dart';
import 'package:yusmus_mobile/core/network/api_client.dart';
import 'package:yusmus_mobile/core/network/api_exception.dart';
import 'package:yusmus_mobile/core/realtime/realtime_client.dart';
import 'package:yusmus_mobile/core/storage/token_store.dart';
import 'package:yusmus_mobile/features/auth/auth_repository.dart';
import 'package:yusmus_mobile/features/settings/pay_rate.dart';
import 'package:yusmus_mobile/features/workers/worker_repository.dart';

const phone = String.fromEnvironment('SMOKE_ADMIN_PHONE');
const password = String.fromEnvironment('SMOKE_ADMIN_PASSWORD');

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final configured = phone.isNotEmpty && password.isNotEmpty;

  test('ADMIN flow against the real API: login, delta sync, detail, approve + realtime event, sessions, logout',
      skip: configured ? false : 'set SMOKE_ADMIN_PHONE / SMOKE_ADMIN_PASSWORD / API_URL', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tokens = MemoryTokenStore();
    var expired = false;
    final api = ApiClient(tokens: tokens, onSessionExpired: () => expired = true);
    final auth = AuthRepository(api, tokens);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = WorkerRepository(api, db, prefs);

    // wrong password is a typed error, not a crash
    await expectLater(auth.adminLogin(phone, 'definitely-wrong'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS')));

    final me = await auth.adminLogin(phone, password);
    expect(me.isAdmin, isTrue);
    expect(await auth.restore(), isNotNull); // token restore path used at app start

    final realtime = RealtimeClient(tokens);
    final events = <RealtimeEvent>[];
    realtime.events.listen(events.add);
    final ready = realtime.connection.firstWhere((c) => c);
    await realtime.connect();
    await ready.timeout(const Duration(seconds: 8));

    await repo.refresh(full: true);
    final pending = await repo.watch(status: 'PENDING_APPROVAL').first;
    expect(pending, isNotEmpty, reason: 'seed one PENDING_APPROVAL worker before running the smoke test');
    final target = pending.first;
    expect(target.collateral, isNotNull);

    final detail = await repo.fetchDetail(target.id);
    expect(detail.collaterals, isNotEmpty);
    expect(detail.hasLocation, isTrue);

    final approved = await repo.approve(target.id, collateralReceived: true);
    expect(approved.status, 'ACTIVE');
    expect((await repo.watch(status: 'ACTIVE').first).map((w) => w.id), contains(target.id));

    // the server pushes the change to every ADMIN device after COMMIT
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!events.any((e) => e.type == 'worker.approved') && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(events.map((e) => e.type), contains('worker.approved'));
    expect(events.firstWhere((e) => e.type == 'worker.approved').data['workerId'], target.id);

    final sessions = await auth.sessions();
    expect(sessions.where((s) => s.current), hasLength(1));

    await realtime.disconnect();
    await auth.logout();
    expect(await tokens.readAccess(), isNull);
    expect(expired, isFalse);
    await db.close();
  });

  test('the ONE 9 m price against the real API: read, change, the change is pushed to every screen, history, restore',
      skip: configured ? false : 'set SMOKE_ADMIN_PHONE / SMOKE_ADMIN_PASSWORD / API_URL', () async {
    final tokens = MemoryTokenStore();
    final api = ApiClient(tokens: tokens, onSessionExpired: () {});
    final auth = AuthRepository(api, tokens);
    final rates = PayRateRepository(api);
    await auth.adminLogin(phone, password);

    final realtime = RealtimeClient(tokens);
    final events = <RealtimeEvent>[];
    realtime.events.listen(events.add);
    final ready = realtime.connection.firstWhere((c) => c);
    await realtime.connect();
    await ready.timeout(const Duration(seconds: 8));

    final before = await rates.current();
    expect(before.kitMeters, 9);
    final target = before.ratePerKit == '30000' ? 35000 : 30000;
    final saved = await rates.change(target, note: 'smoke test');
    expect(saved.ratePerKit, target.toString());
    expect((await rates.current()).ratePerKit, target.toString());

    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!events.any((e) => e.type == 'pay_rate.changed') && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final pushed = events.firstWhere((e) => e.type == 'pay_rate.changed');
    expect(pushed.data['ratePerKit'], target.toString());
    expect(pushed.data['previousRatePerKit'], before.ratePerKit);

    final history = await rates.history();
    expect(history.first.ratePerKit, target.toString());
    expect(history.first.previousRatePerKit, before.ratePerKit);
    expect(history.first.note, 'smoke test');
    expect(history.first.changedBy, isNotNull);

    await rates.change(int.parse(before.ratePerKit)); // leave the price as it was
    await realtime.disconnect();
    await auth.logout();
  });
}
