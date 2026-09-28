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
}
