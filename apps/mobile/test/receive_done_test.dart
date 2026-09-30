import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:diamoraa_mobile/features/work/receive_work_screens.dart';
import 'package:diamoraa_mobile/l10n/app_localizations.dart';

/// «Работа принята!» -> «На главную» must actually close the scan / done screens that sit on top of «Главная».
void main() {
  testWidgets('«На главную» after receiving work goes back to the home tab', (tester) async {
    final router = GoRouter(initialLocation: '/worker/home', routes: [
      GoRoute(
        path: '/worker/home',
        builder: (context, _) => Scaffold(
          body: Column(children: [
            const Text('главная'),
            TextButton(
              // like the app: scan screen pushed over home, then replaced by the done screen
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (ctx) => Scaffold(
                    body: TextButton(onPressed: () => Navigator.of(ctx).pushReplacement(MaterialPageRoute<void>(builder: (_) => const ReceiveDoneScreen())), child: const Text('принять')),
                  ))),
              child: const Text('сканировать'),
            ),
          ]),
        ),
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.tap(find.text('сканировать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('принять'));
    await tester.pumpAndSettle();
    expect(find.byType(ReceiveDoneScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('receiveGoHome')));
    await tester.pumpAndSettle();
    expect(find.byType(ReceiveDoneScreen), findsNothing);
    expect(find.text('главная'), findsOneWidget);
  });
}
