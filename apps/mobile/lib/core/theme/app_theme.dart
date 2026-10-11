import 'package:flutter/material.dart';

/// ALL colours, radii and text styles live here (D-020). Screens ask the theme, never hard-code a style, so the owner's
/// visual feedback ("bigger buttons", "another colour") is a change in this file only.
class AppTokens {
  const AppTokens._();
  static const seed = Color(0xFFA3324F); // rose
  static const radius = 16.0;
  static const cardPadding = EdgeInsets.all(16);
  static const screenPadding = EdgeInsets.symmetric(horizontal: 16);
  static const buttonHeight = 52.0;
  static const ok = Color(0xFF1B7F4B);
  static const warn = Color(0xFFB26A00);
}

class AppTheme {
  const AppTheme._();

  /// A small phone (narrower than 360 dp or shorter than 640 dp, e.g. 320 × 480): the same app, tighter - a lower top
  /// bar and bottom bar, denser lists, buttons and fields, a touch smaller text - so a screen shows its content, not
  /// just its header (owner, 2026-10-11, on a 320 × 480 phone).
  static bool isCompact(Size s) => s.width < 360 || s.height < 640;

  static ThemeData compact(ThemeData t) => t.copyWith(
        visualDensity: VisualDensity.compact,
        appBarTheme: t.appBarTheme.copyWith(toolbarHeight: 48, titleTextStyle: t.textTheme.titleLarge?.copyWith(color: t.colorScheme.onSurface)),
        navigationBarTheme: t.navigationBarTheme.copyWith(height: 58),
        cardTheme: t.cardTheme.copyWith(margin: const EdgeInsets.symmetric(vertical: 3)),
        listTileTheme: const ListTileThemeData(visualDensity: VisualDensity.compact, minVerticalPadding: 4),
        tabBarTheme: t.tabBarTheme.copyWith(labelPadding: const EdgeInsets.symmetric(horizontal: 8)),
        searchBarTheme: const SearchBarThemeData(constraints: BoxConstraints(minHeight: 44, maxHeight: 44)),
        filledButtonTheme: FilledButtonThemeData(style: t.filledButtonTheme.style?.copyWith(minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)))),
        outlinedButtonTheme: OutlinedButtonThemeData(style: t.outlinedButtonTheme.style?.copyWith(minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)))),
        inputDecorationTheme: t.inputDecorationTheme.copyWith(isDense: true),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: AppTokens.seed, brightness: b);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Manrope');
    // headings a touch bolder and tighter: friendlier and easier to scan on a small phone
    final text = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Manrope',
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius), side: BorderSide(color: scheme.outlineVariant)),
        // a little air between stacked cards everywhere (lists like «Настройки» had them touching)
        margin: const EdgeInsets.symmetric(vertical: 5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppTokens.buttonHeight), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius))),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(AppTokens.buttonHeight), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius))),
      ),
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radius)), filled: true, fillColor: scheme.surfaceContainerLowest),
      appBarTheme: AppBarTheme(centerTitle: false, backgroundColor: scheme.surface, scrolledUnderElevation: 0),
      navigationBarTheme: NavigationBarThemeData(indicatorColor: scheme.primaryContainer),
    );
  }
}
