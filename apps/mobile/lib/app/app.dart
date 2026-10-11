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
      builder: (context, child) {
        // a very large system font made every screen scroll and broke words: follow it, but at most +10 %
        final scaled = MediaQuery.withClampedTextScaling(maxScaleFactor: 1.1, child: child!);
        // a small phone (320 × 480): the tighter theme and text 6 % smaller, so screens show content, not headers
        final size = MediaQuery.sizeOf(context);
        if (!AppTheme.isCompact(size)) return scaled;
        final theme = Theme.of(context);
        final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scaler.scale(1) * (size.width < 360 ? 0.94 : 1))),
          child: Theme(data: AppTheme.compact(theme), child: child),
        );
      },
    );
  }
}
