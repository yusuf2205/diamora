import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yusmus_mobile/core/network/api_exception.dart';
import 'package:yusmus_mobile/core/realtime/realtime_client.dart';
import 'package:yusmus_mobile/core/ui/widgets.dart';
import 'package:yusmus_mobile/features/auth/models.dart';
import 'package:yusmus_mobile/features/workers/models.dart';

// Payloads copied from the API integration tests (apps/api/test/*.spec.ts) — the contract both sides rely on.
const workerListItem = {
  'id': '01a0c48f-5c24-7f32-8af1-f3e460108c75',
  'code': 'W-0007',
  'fullName': 'Малика Каримова',
  'phone': '+998901234567',
  'secondaryPhone': null,
  'status': 'PENDING_APPROVAL',
  'latitude': 41.2995,
  'longitude': 69.2401,
  'locationReceivedAt': '2026-09-21T10:00:00.000Z',
  'balance': '0',
  'createdAt': '2026-09-21T10:00:00.000Z',
  'updatedAt': '2026-09-21T10:00:00.000Z',
  'collateral': {'id': 'c1', 'type': 'MONEY', 'status': 'PENDING', 'amount': '1500000', 'description': null},
};

void main() {
  test('worker list item parses (money stays a string, GPS as doubles, pending flag)', () {
    final w = Worker.fromJson(workerListItem);
    expect(w.fullName, 'Малика Каримова');
    expect(w.isPending, isTrue);
    expect(w.hasLocation, isTrue);
    expect(w.latitude, closeTo(41.2995, 1e-6));
    expect(w.collateral!.amount, '1500000');
    expect(w.collateral!.isMoney, isTrue);
    expect(w.searchText, contains('w-0007'));
  });

  test('worker detail parses collaterals with signed photo URLs', () {
    final w = Worker.fromJson({
      ...workerListItem,
      'notes': 'заметка',
      'collaterals': [
        {
          'id': 'c2',
          'code': 'COL-000002',
          'type': 'ITEM',
          'status': 'HELD',
          'amount': null,
          'description': 'Золотое кольцо 585',
          'estimatedValue': '4200000',
          'storageLocation': 'Сейф A',
          'photos': [
            {'id': 'p1', 'file': {'id': 'f1', 'url': 'https://api.example.uz/v1/files/f1/original?exp=1&sig=x', 'thumbUrl': 'https://api.example.uz/v1/files/f1/thumb?exp=1&sig=y'}}
          ],
        }
      ],
    });
    expect(w.collaterals.single.status, 'HELD');
    expect(w.collaterals.single.photos.single.file!.thumbUrl, contains('/thumb?'));
    expect(w.collaterals.single.isMoney, isFalse);
  });

  test('session parses for both roles', () {
    final a = Session.fromJson({'id': 'u1', 'fullName': 'Owner', 'phone': '+998901112233', 'role': 'ADMIN', 'workerId': null});
    final w = Session.fromJson({'id': 'u2', 'fullName': 'Малика', 'phone': '+998901234567', 'role': 'WORKER', 'workerId': 'w1'});
    expect([a.isAdmin, a.isWorker, w.isAdmin, w.isWorker], [true, false, false, true]);
    expect(w.workerId, 'w1');
  });

  test('ApiException maps the uniform error envelope, Retry-After and network failures', () {
    final req = RequestOptions(path: '/x');
    final e = ApiException.fromDio(DioException(
      requestOptions: req,
      response: Response(
        requestOptions: req,
        statusCode: 429,
        headers: Headers.fromMap({'retry-after': ['900']}),
        data: {'error': {'code': 'RATE_LIMITED', 'message': 'Too many attempts', 'requestId': 'abc'}},
      ),
    ));
    expect((e.code, e.status, e.retryAfterSeconds), ('RATE_LIMITED', 429, 900));
    expect(ApiException.fromDio(DioException(requestOptions: req)).isOffline, isTrue);
  });

  test('realtime envelope parses', () {
    final e = RealtimeEvent.fromJson({'id': 'e1', 'type': 'worker.created', 'occurredAt': '2026-09-21T10:00:00.000Z', 'data': {'workerId': 'w1', 'fullName': 'Малика'}});
    expect(e.type, 'worker.created');
    expect(e.data['workerId'], 'w1');
    expect(e.occurredAt.isUtc, isTrue);
  });

  test('money formatting groups thousands', () {
    expect(formatUzs('1500000'), '1 500 000');
    expect(formatUzs('0'), '0');
    expect(formatUzs(null), '—');
    expect(initials('Малика Каримова'), 'МК');
  });
}
