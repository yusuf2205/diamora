import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yusmus_mobile/core/db/app_database.dart';
import 'package:yusmus_mobile/core/network/api_client.dart';
import 'package:yusmus_mobile/core/storage/token_store.dart';
import 'package:yusmus_mobile/features/workers/worker_repository.dart';

import 'models_test.dart' show workerListItem;

class MockApi extends Mock implements ApiClient {}

Map<String, dynamic> worker(String id, String name, String status, {String phone = '+998901111111'}) =>
    {...workerListItem, 'id': id, 'fullName': name, 'status': status, 'phone': phone, 'code': 'W-$id'};

void main() {
  late AppDatabase db;
  late MockApi api;
  late SharedPreferences prefs;
  late WorkerRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = MockApi();
    repo = WorkerRepository(api, db, prefs);
  });
  tearDown(() => db.close());

  void servePages(List<Map<String, dynamic>> pages) {
    var i = 0;
    when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => pages[i++]);
  }

  test('refresh follows keyset pages, fills the cache and remembers the sync time (delta sync next time)', () async {
    servePages([
      {'items': [worker('1', 'Анна', 'PENDING_APPROVAL'), worker('2', 'Бахора', 'ACTIVE', phone: '+998902222222')], 'nextCursor': 'c1'},
      {'items': [worker('3', 'Вера', 'ACTIVE', phone: '+998903333333')], 'nextCursor': null},
    ]);
    await repo.refresh();
    expect((await repo.watch().first).map((w) => w.fullName).toSet(), {'Анна', 'Бахора', 'Вера'});
    expect(prefs.getString('workers_last_sync'), isNotNull);

    // second refresh asks only for changes since the last sync
    servePages([{'items': <Map<String, dynamic>>[], 'nextCursor': null}]);
    await repo.refresh();
    final q = verify(() => api.getJson('/workers', query: captureAny(named: 'query'))).captured.last as Map<String, dynamic>;
    expect(q['updatedSince'], isA<String>());
    expect(q.containsKey('cursor'), isFalse);
  });

  test('offline reads: filter by status and by search text (name, phone, code) straight from the cache', () async {
    servePages([{'items': [worker('1', 'Анна Новая', 'PENDING_APPROVAL'), worker('2', 'Бахора', 'ACTIVE', phone: '+998902222222')], 'nextCursor': null}]);
    await repo.refresh();
    expect((await repo.watch(status: 'PENDING_APPROVAL').first).map((w) => w.fullName), ['Анна Новая']);
    expect((await repo.watch(query: 'бахор').first).single.fullName, 'Бахора');
    expect((await repo.watch(query: '902222').first).single.fullName, 'Бахора');
    expect(await repo.watch(status: 'ACTIVE', query: 'анна').first, isEmpty);
  });

  test('approve is sent with an Idempotency-Key and updates the cache from the server answer', () async {
    servePages([{'items': [worker('1', 'Анна', 'PENDING_APPROVAL')], 'nextCursor': null}]);
    await repo.refresh();
    when(() => api.postJson('/workers/1/approve', body: any(named: 'body'), idempotencyKey: any(named: 'idempotencyKey')))
        .thenAnswer((_) async => worker('1', 'Анна', 'ACTIVE'));
    final w = await repo.approve('1', collateralReceived: true);
    expect(w.status, 'ACTIVE');
    final call = verify(() => api.postJson('/workers/1/approve', body: captureAny(named: 'body'), idempotencyKey: captureAny(named: 'idempotencyKey')));
    expect((call.captured[0] as Map)['collateralReceived'], true);
    expect((call.captured[1] as String).length, greaterThan(20));
    expect((await repo.watch(status: 'ACTIVE').first).single.fullName, 'Анна');
    expect(await repo.watch(status: 'PENDING_APPROVAL').first, isEmpty);
  });

  test('clear() wipes the cache and the sync marker (next user must not see this data)', () async {
    servePages([{'items': [worker('1', 'Анна', 'ACTIVE')], 'nextCursor': null}]);
    await repo.refresh();
    await repo.clear();
    expect(await repo.watch().first, isEmpty);
    expect(prefs.getString('workers_last_sync'), isNull);
  });

  test('token store contract: memory implementation keeps tokens and a stable install id until cleared', () async {
    final s = MemoryTokenStore();
    await s.save(access: 'a', refresh: 'r');
    expect(await s.readAccess(), 'a');
    final id = await s.installId();
    await s.clear();
    expect(await s.readRefresh(), isNull);
    expect(await s.installId(), id);
  });
}
