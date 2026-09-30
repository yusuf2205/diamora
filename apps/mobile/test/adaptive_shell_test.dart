import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:diamoraa_mobile/app/shells.dart';

/// Tablet (>= 600 dp): a side rail with every label written out; phone: the bottom bar.
void main() {
  Future<void> pump(WidgetTester tester, Size size, {Set<int> fullWidth = const {}, bool chat = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/a', routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdaptiveShell(
          shell: shell,
          body: shell,
          fullWidthBranches: fullWidth,
          destinations: [
            (Icons.map_rounded, Icons.map_rounded, 'Карта'),
            (Icons.inventory_2_rounded, Icons.inventory_2_rounded, 'Склад'),
            if (chat) (Icons.forum_outlined, Icons.forum_rounded, 'Чат'),
          ],
          chatIndex: chat ? 2 : null,
          badges: chat ? const {2: 7} : const {},
        ),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/a', builder: (_, _) => const SizedBox.expand(child: Align(alignment: Alignment.topLeft, child: Text('экран A'))))]),
          StatefulShellBranch(routes: [GoRoute(path: '/b', builder: (_, _) => const Text('экран B'))]),
          if (chat) StatefulShellBranch(routes: [GoRoute(path: '/c', builder: (_, _) => const Text('экран чата'))]),
        ],
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('tablet: side rail with labels; tapping a label switches the screen', (tester) async {
    await pump(tester, const Size(800, 1280));
    expect(find.byKey(const Key('tabletRail')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Карта'), findsOneWidget);
    expect(find.text('Склад'), findsOneWidget);
    expect(tester.getSize(find.byIcon(Icons.map_rounded)).width, greaterThanOrEqualTo(30)); // large side icons
    await tester.tap(find.text('Склад'));
    await tester.pumpAndSettle();
    expect(find.text('экран B'), findsOneWidget);
  });

  testWidgets('tablet landscape: the rail is widened to icon + text', (tester) async {
    await pump(tester, const Size(1280, 800));
    expect(tester.widget<NavigationRail>(find.byKey(const Key('tabletRail'))).extended, isTrue);
    expect(find.text('Склад'), findsOneWidget);
  });

  testWidgets('tablet: a screen is kept to a readable width in the middle, the full-width tab (map) is not', (tester) async {
    await pump(tester, const Size(1600, 1000), fullWidth: {1});
    expect(tester.getSize(find.text('экран A')).width, lessThanOrEqualTo(AdaptiveShell.contentMaxWidth));
    expect(tester.getTopLeft(find.text('экран A')).dx, greaterThan(300)); // centred, not glued to the rail
  });

  testWidgets('phone: bottom bar, no rail', (tester) async {
    await pump(tester, const Size(412, 900));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('tabletRail')), findsNothing);
  });

  for (final size in [const Size(800, 1280), const Size(1280, 800)]) {
    testWidgets('tablet ${size.width < size.height ? 'portrait' : 'landscape'}: the chat is a big separate button above the other tabs, with its count', (tester) async {
      await pump(tester, size, chat: true);
      final rail = tester.widget<NavigationRail>(find.byKey(const Key('tabletRail')));
      expect(rail.destinations.length, 2); // the chat is not one of the plain tabs
      expect(find.byKey(const Key('railChat')), findsOneWidget);
      expect(find.byKey(const Key('tabBadge-2')), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const Key('railChat'))).dy, lessThan(tester.getTopLeft(find.text('Карта')).dy));
      await tester.tap(find.byKey(const Key('railChat')));
      await tester.pumpAndSettle();
      expect(find.text('экран чата'), findsOneWidget);
      expect(tester.widget<NavigationRail>(find.byKey(const Key('tabletRail'))).selectedIndex, isNull);
      await tester.tap(find.text('Склад'));
      await tester.pumpAndSettle();
      expect(find.text('экран B'), findsOneWidget);
    });
  }

  testWidgets('phone: the chat tab is a coloured round button in the bar', (tester) async {
    await pump(tester, const Size(412, 900), chat: true);
    expect(find.byKey(const Key('chatTabButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chatTabButton')));
    await tester.pumpAndSettle();
    expect(find.text('экран чата'), findsOneWidget);
  });
}