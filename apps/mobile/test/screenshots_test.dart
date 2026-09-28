// Visual check of every main screen on the smallest supported phone (320 dp wide) with the REAL font and icons.
// Not part of the normal run:   SCREENSHOTS=1 flutter test test/screenshots_test.dart   -> build/screens/*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:diamoraa_mobile/features/auth/models.dart';

import 'app_flow_test.dart' show MockApi;
import 'catalog_test.dart' show appWith, tearDownDb;
import 'models_test.dart' show workerListItem;
import 'overview_test.dart' show dash;

final _enabled = Platform.environment['SCREENSHOTS'] == '1';

Future<void> _loadFonts() async {
  final manrope = FontLoader('Manrope');
  for (final w in [400, 500, 600, 700, 800]) {
    manrope.addFont(rootBundle.load('assets/fonts/Manrope-$w.ttf'));
  }
  await manrope.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
  await loader.load();
}

Future<void> shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/screens').createSync(recursive: true);
    File('build/screens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MockApi api;
  setUpAll(() async { if (_enabled) await _loadFonts(); });
  setUp(() {
    api = MockApi();
    when(() => api.getJson(any(), query: any(named: 'query'))).thenAnswer((_) async => {'items': <Object>[]});
    when(() => api.getList(any())).thenAnswer((_) async => <Object>[]);
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  const longName = 'Нигора Рахматуллаева-Исмаилова';
  final assignment = {
    'id': 'a1', 'code': 'A-00001', 'status': 'READY_TO_DELIVER', 'kitCount': 2, 'plannedMeters': 18.0, 'reportedMeters': 0.0, 'expectedPayment': '60000',
    'dueAt': '2026-10-05T12:00:00Z', 'qrCode': 'YQ1.ABCDEFGHJKMN',
    'worker': {'id': 'w1', 'fullName': longName, 'phone': '+998901234567'}, 'product': {'id': 'p1', 'name': 'Свадебный комплект «Роза»'},
    'color': {'id': 'c1', 'name': 'Жемчужно-белый', 'hex': '#f4e7d7'},
    'materials': [{'materialId': 'm1', 'quantity': 18, 'name': 'Органза', 'unit': 'METER'}, {'materialId': 'm2', 'quantity': 80, 'name': 'Бисер', 'unit': 'GRAM'}],
    'statusHistory': <Object>[], 'deliveries': <Object>[], 'handoffTimeline': <Object>[],
    'handoff': {'id': 'h1', 'status': 'AWAITING_WORKER', 'startedAt': '2026-09-28T09:00:00Z', 'expiresAt': '2026-09-28T11:00:00Z', 'expired': false,
      'staff': {'id': 's1', 'fullName': 'Юсуф Адилов', 'role': 'SUPER_ADMIN'}, 'workerScannedAt': null, 'workerAcceptedAt': null,
      'problemReason': null, 'problemComment': null, 'hasLocation': false},
  };

  testWidgets('staff screens', (tester) async {
    phone(tester);
    when(() => api.getJson('/dashboard')).thenAnswer((_) async => dash());
    final worker = {...workerListItem, 'id': 'w1', 'fullName': longName, 'status': 'ACTIVE', 'balance': '1250000', 'manager': {'id': 'm1', 'fullName': 'Гульнора Юсупова'}};
    when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {'items': [worker], 'nextCursor': null});
    when(() => api.getJson('/workers/w1')).thenAnswer((_) async => {...worker, 'collaterals': <Object>[], 'qrCode': 'YQ1.ABCDEFGHJKMN'});
    when(() => api.getJson('/admin/workers/w1/ledger')).thenAnswer((_) async => {'workerId': 'w1', 'balance': '1250000', 'earned': '3600000', 'paid': '2350000', 'history': <Object>[]});
    when(() => api.getJson('/admin/assignments', query: any(named: 'query'))).thenAnswer((_) async => {'items': [assignment]});
    when(() => api.getJson('/admin/assignments/a1')).thenAnswer((_) async => assignment);
    when(() => api.getJson('/admin/job-requests')).thenAnswer((_) async => {'items': [
          {'id': 'r1', 'status': 'PENDING', 'kitCount': 2, 'meters': 18, 'note': 'к пятнице', 'decisionNote': null, 'createdAt': '2026-09-28T09:00:00Z',
           'worker': {'id': 'w1', 'code': 'W-0001', 'fullName': longName, 'phone': '+998901234567'}, 'product': {'id': 'p1', 'name': 'Свадебный комплект «Роза»'},
           'variant': {'id': 'v1', 'label': null}, 'color': {'id': 'c1', 'name': 'Жемчужно-белый', 'hex': '#f4e7d7'}, 'assignmentId': null},
        ]});
    when(() => api.getJson('/locations')).thenAnswer((_) async => {'items': [
          {'userId': 'u9', 'role': 'WORKER', 'fullName': longName, 'worker': {'id': 'w1', 'code': 'W-0007', 'managerId': 'm1'},
           'latitude': 41.311081, 'longitude': 69.240562, 'ageSeconds': 17460, 'stale': true, 'freshness': 'STALE', 'online': false},
          {'userId': 'm1', 'role': 'MANAGER', 'fullName': 'Гульнора Абдурахмановна Юсупова', 'latitude': 41.3, 'longitude': 69.2, 'ageSeconds': 30, 'stale': false, 'freshness': 'LIVE', 'online': true},
        ]});
    final owner = Session.fromJson({
      'id': 'me', 'fullName': 'Юсуф Адилов', 'phone': '+998901112233', 'role': 'SUPER_ADMIN',
      'permissions': ['USER_VIEW_ALL', 'USER_CREATE', 'AUDIT_VIEW', 'WORKER_VIEW_ALL', 'WORKER_APPROVE', 'WORKER_UPDATE', 'WORKER_DELETE', 'WORKER_ASSIGN_MANAGER',
        'ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_CREATE', 'FINANCE_VIEW_ALL', 'CASH_PAYOUT', 'PAY_RATE_MANAGE', 'SETTINGS_MANAGE', 'MAP_VIEW_ALL', 'LIVE_LOCATION_VIEW_ALL',
        'INVENTORY_VIEW', 'CATALOG_VIEW'],
    });
    await tester.pumpWidget(RepaintBoundary(child: await appWith(owner, api)));
    await shot(tester, 's01-overview');
    await tester.tap(find.byIcon(Icons.groups_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Все'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await shot(tester, 's02-workers');
    await tester.tap(find.text(longName).first);
    await shot(tester, 's03-worker-card');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shot(tester, 's04-worker-card-2');
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.map_rounded).last);
    await shot(tester, 's05-map');
    await tester.tap(find.byIcon(Icons.list_rounded));
    await shot(tester, 's06-locations');
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz_rounded).last);
    await shot(tester, 's07-more');
    await tearDownDb(tester);
  }, skip: !_enabled);

  testWidgets('worker screens', (tester) async {
    phone(tester);
    when(() => api.getJson('/workers/me')).thenAnswer((_) async => {...workerListItem, 'fullName': longName, 'status': 'ACTIVE', 'collaterals': <Object>[], 'balance': '1250000'});
    when(() => api.getJson('/workers/me/collateral')).thenAnswer((_) async => {'items': <Object>[]});
    when(() => api.getJson('/settings/pay-rate')).thenAnswer((_) async => {'ratePerKit': '30000', 'kitMeters': 9, 'updatedAt': '2026-09-21T09:00:00Z'});
    when(() => api.getJson('/work/earnings')).thenAnswer((_) async => {'workerId': 'w1', 'balance': '1250000', 'earned': '3600000', 'paid': '2350000', 'history': <Object>[]});
    when(() => api.getJson('/work/current')).thenAnswer((_) async => assignment);
    when(() => api.getJson('/work/requests')).thenAnswer((_) async => {'items': [
          {'id': 'r1', 'status': 'PENDING', 'kitCount': 2, 'meters': 18, 'note': null, 'decisionNote': null, 'createdAt': DateTime.now().toUtc().toIso8601String(),
           'worker': {'id': 'w1', 'code': 'W-0001', 'fullName': longName, 'phone': '+998901234567'}, 'product': {'id': 'p1', 'name': 'Свадебный комплект «Роза»'},
           'variant': {'id': 'v1', 'label': null}, 'color': {'id': 'c1', 'name': 'Жемчужно-белый', 'hex': '#f4e7d7'}, 'assignmentId': null},
        ]});
    final worker = Session.fromJson({'id': 'u2', 'fullName': longName, 'phone': '+998901234567', 'role': 'WORKER', 'workerId': 'w1'});
    await tester.pumpWidget(RepaintBoundary(child: await appWith(worker, api)));
    await shot(tester, 'w01-catalog');
    await tester.tap(find.text('Главная').last);
    await shot(tester, 'w02-home');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shot(tester, 'w03-home-2');
    await tester.tap(find.text('Профиль').last);
    await shot(tester, 'w04-profile');
    await tearDownDb(tester);
  }, skip: !_enabled);
}
