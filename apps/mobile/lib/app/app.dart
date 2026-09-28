import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/profile/locale_controller.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';

class DiamoraaApp extends ConsumerWidget {
  const DiamoraaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Diamoraa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: ref.watch(localeControllerProvider),
      supportedLocales: supportedLocales,
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      routerConfig: ref.watch(routerProvider),
      // a very large system font made every screen scroll and broke words: follow it, but at most +10 %
      builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.1, child: child!),
    );
  }
}
