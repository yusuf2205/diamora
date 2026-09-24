import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:yusmus_mobile/app/router.dart';
import 'package:yusmus_mobile/core/providers.dart';
import 'package:yusmus_mobile/core/realtime/realtime_client.dart';
import 'package:yusmus_mobile/core/storage/token_store.dart';
import 'package:yusmus_mobile/features/auth/auth_controller.dart';
import 'package:yusmus_mobile/features/auth/models.dart';
import 'package:yusmus_mobile/features/auth/telegram_pending_screen.dart';
import 'package:yusmus_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi, appWith;

/// Exposes the ambient `Ref` a real widget tree would hand `handleTelegramLink` via `ref.read`
/// inside `routerProvider`'s builder — there is no widget tree here, so a container reads it back out.
final _refProvider = Provider<Ref>((ref) => ref);

Future<ProviderContainer> _telegramContainer(MockApi api) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final realtime = MockRealtimeClient();
  when(realtime.connect).thenAnswer((_) async {});
  final c = ProviderContainer(overrides: [
    apiClientProvider.overrideWithValue(api),
    tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    sharedPrefsProvider.overrideWithValue(prefs),
    realtimeClientProvider.overrideWithValue(realtime), // a real Socket.IO connect() leaves pending timers in tests
  ]);
  await c.read(authControllerProvider.future); // let the initial "restore session" build settle first
  return c;
}

/// Stands in for the real platform's Telegram/browser launch (url_launcher_platform_interface, same idea as
/// mocking any other platform channel — there is no real OS to open Telegram in a widget test).
class FakeUrlLauncher extends UrlLauncherPlatform {
  String? lastUrl;
  bool result = true;
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> canLaunch(String url) async => true;
  @override
  Future<bool> launch(String url, {required bool useSafariVC, required bool useWebView, required bool enableJavaScript, required bool enableDomStorage, required bool universalLinksOnly, required Map<String, String> headers, String? webOnlyWindowName}) async {
    lastUrl = url;
    return result;
  }
}

class MockRealtimeClient extends Mock implements RealtimeClient {}

Widget pendingHarness(String status, {String? reason}) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TelegramPendingScreen(status: status, reason: reason),
    );

void main() {
  late MockApi api;
  late FakeUrlLauncher launcher;
  setUp(() {
    api = MockApi();
    launcher = FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  group('Login screen: WORKER auth is Telegram-only', () {
    testWidgets('the "Войти через Telegram" button is there from the start, no phone typed yet', (tester) async {
      await tester.pumpWidget(await appWith(null, api));
      await tester.pumpAndSettle();
      expect(find.text('Войти через Telegram'), findsOneWidget);
    });

    testWidgets('tapping it opens the bot deep link the server hands back — never a link the app makes up itself', (tester) async {
      when(() => api.postJson('/auth/telegram/session', body: any(named: 'body'), skipAuth: true))
          .thenAnswer((_) async => {'deepLink': 'https://t.me/diamora1_bot?start=abc123xyz', 'expiresAt': '2026-09-24T12:00:00.000Z'});
      await tester.pumpWidget(await appWith(null, api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Войти через Telegram'));
      await tester.pumpAndSettle();

      verify(() => api.postJson('/auth/telegram/session', body: any(named: 'body'), skipAuth: true)).called(1);
      expect(launcher.lastUrl, 'https://t.me/diamora1_bot?start=abc123xyz');
    });
  });

  group('AuthController.telegramExchange: only an ACTIVE worker ever gets signed in', () {
    final container = _telegramContainer;

    testWidgets('a real session comes back: the controller signs her in', (tester) async {
      when(() => api.postJson('/auth/telegram/exchange', body: any(named: 'body'), skipAuth: true)).thenAnswer((_) async => {
            'accessToken': 'at', 'refreshToken': 'rt',
            'user': {'id': 'w1', 'fullName': 'Малика', 'phone': '+998901234567', 'role': 'WORKER', 'workerId': 'wp1'},
          });
      final c = await container(api);
      addTearDown(c.dispose);
      final outcome = await c.read(authControllerProvider.notifier).telegramExchange('ticket-abc');
      expect(outcome, isA<TelegramLoggedIn>());
      expect(c.read(authControllerProvider).value?.workerId, 'wp1');
    });

    testWidgets('PENDING_APPROVAL: no session is ever created, the outcome says so', (tester) async {
      when(() => api.postJson('/auth/telegram/exchange', body: any(named: 'body'), skipAuth: true)).thenAnswer((_) async => {'status': 'PENDING_APPROVAL'});
      final c = await container(api);
      addTearDown(c.dispose);
      final outcome = await c.read(authControllerProvider.notifier).telegramExchange('ticket-abc');
      expect(outcome, isA<TelegramNotReady>());
      expect((outcome as TelegramNotReady).status, 'PENDING_APPROVAL');
      expect(c.read(authControllerProvider).value, isNull);
    });

    testWidgets('REJECTED carries the reason through, still no session', (tester) async {
      when(() => api.postJson('/auth/telegram/exchange', body: any(named: 'body'), skipAuth: true)).thenAnswer((_) async => {'status': 'REJECTED', 'rejectedReason': 'Не подходит'});
      final c = await container(api);
      addTearDown(c.dispose);
      final outcome = await c.read(authControllerProvider.notifier).telegramExchange('ticket-abc') as TelegramNotReady;
      expect(outcome.status, 'REJECTED');
      expect(outcome.reason, 'Не подходит');
      expect(c.read(authControllerProvider).value, isNull);
    });
  });

  group('TelegramPendingScreen: never the Worker UI for an unapproved/rejected/paused mastеritsa', () {
    testWidgets('PENDING_APPROVAL', (tester) async {
      await tester.pumpWidget(pendingHarness('PENDING_APPROVAL'));
      await tester.pumpAndSettle();
      expect(find.text('Заявка отправлена'), findsOneWidget);
      expect(find.text('На экран входа'), findsOneWidget);
    });

    testWidgets('REJECTED shows the admin-provided reason', (tester) async {
      await tester.pumpWidget(pendingHarness('REJECTED', reason: 'Не подходит по условиям'));
      await tester.pumpAndSettle();
      expect(find.text('Заявка отклонена'), findsOneWidget);
      expect(find.text('Не подходит по условиям'), findsOneWidget);
    });

    testWidgets('PAUSED', (tester) async {
      await tester.pumpWidget(pendingHarness('PAUSED'));
      await tester.pumpAndSettle();
      expect(find.text('Профиль приостановлен'), findsOneWidget);
    });
  });

  group('handleTelegramLink: app_links cold-start can deliver the same URI twice', () {
    GoRouter router() => GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/telegram-pending', builder: (_, _) => const SizedBox()),
        ]);

    testWidgets('the ticket is only ever exchanged once, however many times the link arrives', (tester) async {
      when(() => api.postJson('/auth/telegram/exchange', body: any(named: 'body'), skipAuth: true))
          .thenAnswer((_) async => {'status': 'PENDING_APPROVAL'});
      final c = await _telegramContainer(api);
      addTearDown(c.dispose);
      final ref = c.read(_refProvider);
      final handled = <String>{};
      final uri = Uri.parse('https://diamoraa.uz/app/auth/telegram?t=ticket-dup');

      // getInitialLink() and uriLinkStream firing "concurrently" on a cold start, both racing to add to the same set.
      await Future.wait([
        handleTelegramLink(ref, router(), uri, handled),
        handleTelegramLink(ref, router(), uri, handled),
      ]);

      verify(() => api.postJson('/auth/telegram/exchange', body: any(named: 'body'), skipAuth: true)).called(1);
    });

    testWidgets('a different ticket is not swallowed by an earlier one', (tester) async {
      when(() => api.postJson('/auth/telegram/exchange', body: any(named: 'body'), skipAuth: true))
          .thenAnswer((_) async => {'status': 'PENDING_APPROVAL'});
      final c = await _telegramContainer(api);
      addTearDown(c.dispose);
      final ref = c.read(_refProvider);
      final handled = <String>{};

      await handleTelegramLink(ref, router(), Uri.parse('https://diamoraa.uz/app/auth/telegram?t=ticket-a'), handled);
      await handleTelegramLink(ref, router(), Uri.parse('https://diamoraa.uz/app/auth/telegram?t=ticket-b'), handled);

      verify(() => api.postJson('/auth/telegram/exchange', body: any(named: 'body'), skipAuth: true)).called(2);
    });
  });
}
