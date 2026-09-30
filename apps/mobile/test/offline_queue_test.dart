import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diamoraa_mobile/core/db/app_database.dart';
import 'package:diamoraa_mobile/core/network/api_exception.dart';
import 'package:diamoraa_mobile/core/offline/offline_queue.dart';

/// Work done without internet: kept on the phone, sent in order when the server answers, never twice.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('no internet: everything stays; back online: sent oldest first, each with the SAME key on every try', () async {
    var online = false;
    final sent = <String>[];
    final keys = <String, Set<String>>{};
    final q = OfflineQueue(db, (kind, p, key) async {
      (keys[p['n'] as String] ??= {}).add(key);
      if (!online) throw ApiException.network();
      sent.add('$kind:${p['n']}');
    });
    await q.add('progress', {'n': '1'});
    await q.add('receive', {'n': '2'});

    expect(await q.flush(), 0); // the first one fails -> the rest is not even tried
    expect(await q.flush(), 0);
    expect((await q.watch().first).length, 2);
    expect((await q.watch().first).first.attempts, 2);

    online = true;
    expect(await q.flush(), 2);
    expect(sent, ['progress:1', 'receive:2']);
    expect(keys['1']!.length, 1); // one idempotency key for all tries: the server counts it once
    expect(await q.watch().first, isEmpty);
  });

  test('the server says «no» (a 4xx): kept with the reason for her to see, not retried, the next one still goes', () async {
    final q = OfflineQueue(db, (kind, p, key) async {
      if (p['n'] == 'bad') throw ApiException(code: 'ASSIGNMENT_NOT_OPEN', message: 'closed', status: 409);
    });
    await q.add('progress', {'n': 'bad'});
    await q.add('progress', {'n': 'ok'});
    expect(await q.flush(), 1);
    final left = await q.watch().first;
    expect(left.single.lastError, 'ASSIGNMENT_NOT_OPEN');
    expect(await q.flush(), 0); // never retried
    await q.dismiss(left.single.id);
    expect(await q.watch().first, isEmpty);
  });

  test('a server that is off (Cloudflare 530) or overloaded counts as «try later», a 4xx does not', () {
    expect(isRetryable(ApiException.network()), isTrue);
    expect(isRetryable(ApiException(code: 'UNKNOWN', message: '', status: 530)), isTrue);
    expect(isRetryable(ApiException(code: 'RATE', message: '', status: 429)), isTrue);
    expect(isRetryable(ApiException(code: 'VALIDATION', message: '', status: 400)), isFalse);
  });

  test('screens without internet show the last good answer', () async {
    final cache = ResponseCache(db);
    expect(await cache.get('k', () async => {'v': 1}, (j) => (j as Map)['v']), 1);
    expect(await cache.get('k', () async => throw ApiException.network(), (j) => (j as Map)['v']), 1); // from the phone
    expect(() => cache.get('other', () async => throw ApiException.network(), (j) => j), throwsA(isA<ApiException>())); // nothing saved yet
    expect(() => cache.get('k', () async => throw ApiException(code: 'FORBIDDEN', message: '', status: 403), (j) => j), throwsA(isA<ApiException>())); // a real «no» is never hidden
  });
}
