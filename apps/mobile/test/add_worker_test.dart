import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:diamoraa_mobile/core/providers.dart';
import 'package:diamoraa_mobile/features/auth/auth_controller.dart';
import 'package:diamoraa_mobile/features/auth/models.dart';
import 'package:diamoraa_mobile/features/workers/add_worker_sheet.dart';
import 'package:diamoraa_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;

class _Auth extends AuthController {
  @override
  Future<Session?> build() async => const Session(id: 'me', fullName: 'Owner', phone: '+998901112233', role: 'ADMIN', permissions: ['WORKER_APPROVE']);
}

/// «Добавить мастерицу»: name + phone -> a one-time Telegram link shown as a big QR.
void main() {
  testWidgets('name + phone -> «Получить ссылку» -> QR + «Отправить в Telegram» + «Скопировать ссылку»', (tester) async {
    final api = MockApi();
    when(() => api.getJson('/workers/invitations')).thenAnswer((_) async => {'items': <Object>[]});
    when(() => api.postJson('/workers/invitations', body: any(named: 'body'))).thenAnswer((_) async => {
          'id': 'i1', 'fullName': 'Нигора Алиева', 'phone': '+998901234567', 'url': 'https://t.me/diamora1_bot?start=inv_abc',
        });
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api), authControllerProvider.overrideWith(_Auth.new)],
      child: const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AddWorkerSheet()),
      ),
    ));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Получить ссылку');
    expect(tester.widget<FilledButton>(button).onPressed, isNull); // nothing typed yet
    await tester.enterText(find.widgetWithText(TextField, 'Фамилия и имя'), 'Нигора Алиева');
    await tester.enterText(find.widgetWithText(TextField, 'Телефон'), '+998 90 123 45 67');
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();

    final call = verify(() => api.postJson('/workers/invitations', body: captureAny(named: 'body')))..called(1);
    expect(call.captured.single, {'fullName': 'Нигора Алиева', 'phone': '+998 90 123 45 67', 'managerId': null});
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Отправить в Telegram'), findsOneWidget);
    expect(find.text('Скопировать ссылку'), findsOneWidget);
  });

  testWidgets('tablet landscape with the keyboard up: the sheet shows its title and fields above the keyboard', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = MockApi();
    when(() => api.getJson('/workers/invitations')).thenAnswer((_) async => {'items': <Object>[]});
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api), authControllerProvider.overrideWith(_Auth.new)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () => showAddWorkerSheet(context), child: const Text('open'))))),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('formDialog')), findsOneWidget); // a window in the middle, not a bottom sheet
    tester.view.viewInsets = const FakeViewPadding(bottom: 400); // the on-screen keyboard
    await tester.pumpAndSettle();
    const keyboardTop = 800 - 400;
    for (final label in ['Добавить мастерицу', 'Фамилия и имя']) {
      final y = tester.getRect(find.text(label).first);
      expect(y.top, greaterThanOrEqualTo(0), reason: label);
      expect(y.bottom, lessThanOrEqualTo(keyboardTop), reason: label);
    }
  });
}