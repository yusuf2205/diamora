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

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: AppTokens.seed, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius), side: BorderSide(color: scheme.outlineVariant)),
        margin: EdgeInsets.zero,
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
