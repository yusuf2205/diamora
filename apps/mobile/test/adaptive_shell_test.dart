import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:diamoraa_mobile/app/shells.dart';

/// Tablet (>= 600 dp): a side rail with every label written out; phone: the bottom bar.
void main() {
  Future<void> pump(WidgetTester tester, Size size, {Set<int> fullWidth = const {}}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/a', routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdaptiveShell(
          shell: shell,
          body: shell,
          fullWidthBranches: fullWidth,
          destinations: const [(Icons.map_rounded, Icons.map_rounded, 'Карта'), (Icons.inventory_2_rounded, Icons.inventory_2_rounded, 'Склад')],
        ),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/a', builder: (_, _) => const SizedBox.expand(child: Align(alignment: Alignment.topLeft, child: Text('экран A'))))]),
          StatefulShellBranch(routes: [GoRoute(path: '/b', builder: (_, _) => const Text('экран B'))]),
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
}
