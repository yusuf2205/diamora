import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:diamoraa_mobile/core/providers.dart';
import 'package:diamoraa_mobile/core/ui/widgets.dart' show formatUzs;
import 'package:diamoraa_mobile/features/progress/progress_screen.dart';
import 'package:diamoraa_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;

/// «Мой прогресс» (owner, 2026-10-11): her month, the quality bonus, the calculator, the checks with defect photos.
void main() {
  Map<String, dynamic> data({bool qualifies = true, double defect = 0, bool enabled = true}) => {
        'month': '2026-10',
        'thisMonth': {'acceptedMeters': 36, 'defectiveMeters': defect, 'qualityPercent': defect > 0 ? 94.7 : 100, 'earned': '120000'},
        'allTime': {'acceptedMeters': 180, 'defectiveMeters': 2, 'qualityPercent': 98.9, 'checks': 9},
        'best': {'month': '2026-09', 'meters': 54}, 'record': false,
        'bonus': {'enabled': enabled, 'percent': 5, 'maxDefectPercent': 0, 'minMeters': 9, 'qualifies': qualifies, 'defectPercent': defect > 0 ? 5.3 : 0, 'expected': qualifies ? '6000' : '0', 'paidThisMonth': '0'},
        'ratePerKit': '30000', 'kitMeters': 9,
        'checks': [
          {'id': 'c1', 'at': '2026-10-05T10:00:00.000Z', 'code': 'A-1', 'product': 'Бант', 'color': 'Розовый', 'result': 'PARTIALLY_ACCEPTED',
           'broughtMeters': 18, 'acceptedMeters': 17, 'defectiveMeters': 1, 'reworkMeters': 0, 'comment': 'Кривой шов на краю',
           'photos': [{'id': 'p1', 'url': 'https://x/p1', 'thumbUrl': 'https://x/p1t'}]},
        ],
      };

  Future<void> pump(WidgetTester tester, Map<String, dynamic> d) async {
    final api = MockApi();
    when(() => api.getJson('/work/progress')).thenAnswer((_) async => d);
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProgressScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('her month, best month, the bonus she is getting, and the check with the inspector\'s words', (tester) async {
    await pump(tester, data());
    expect(find.text('Мой прогресс'), findsOneWidget);
    expect(find.text('36 м'), findsOneWidget);
    expect(find.text('Лучший месяц: Сентябрь — 54 м'), findsOneWidget);
    expect(find.textContaining('Сейчас вы получаете бонус ≈ ${formatUzs('6000')}'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('«Кривой шов на краю»'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Брак: 1 м'), findsOneWidget);
    expect(find.byType(Image), findsWidgets); // the defect photo
  });

  testWidgets('the calculator: 18 m at 30 000 per 9 m = 60 000, plus the 5 % bonus', (tester) async {
    await pump(tester, data());
    await tester.enterText(find.byKey(const Key('calcMeters')), '18');
    await tester.pump();
    expect(find.text('≈ ${formatUzs('60000')} сум'), findsOneWidget);
    expect(find.text('+ бонус за качество ≈ ${formatUzs('3000')} сум'), findsOneWidget);
  });

  testWidgets('too many defects: told kindly; bonus off: no bonus card at all', (tester) async {
    await pump(tester, data(qualifies: false, defect: 2));
    expect(find.textContaining('больше нормы'), findsOneWidget);
    await pump(tester, data(enabled: false));
    expect(find.text('Бонус за качество'), findsNothing);
  });
}
