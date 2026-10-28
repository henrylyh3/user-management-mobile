import 'package:flutter/material.dart';

/// Hallmark Coral: warm stock, ink controls, coral focus. Native theme tokens.
abstract final class Coral {
  static const paper = Color(0xFFF7F4F1);
  static const cotton = Color(0xFFFCFAF7);
  static const desk = Color(0xFFEFEAE5);
  static const ink = Color(0xFF292522);
  static const muted = Color(0xFF716860);
  static const rule = Color(0xFFDDD5CE);
  static const accent = Color(0xFFB74430);
  static const error = Color(0xFFA12E25);
  static const font = 'General Sans';
}

ThemeData coralTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Coral.accent).copyWith(
    primary: Coral.ink,
    onPrimary: Coral.cotton,
    secondary: Coral.accent,
    onSecondary: Coral.cotton,
    surface: Coral.cotton,
    onSurface: Coral.ink,
    onSurfaceVariant: Coral.muted,
    outline: Coral.muted,
    outlineVariant: Coral.rule,
    error: Coral.error,
    surfaceContainerHighest: Coral.desk,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: Coral.font,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  final button = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    shape: WidgetStatePropertyAll(shape),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(
        fontFamily: Coral.font,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    side: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? const BorderSide(color: Coral.accent, width: 3)
          : null,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: Coral.paper,
    focusColor: Coral.accent.withValues(alpha: .18),
    hoverColor: Coral.accent.withValues(alpha: .08),
    textTheme: base.textTheme.copyWith(
      headlineMedium: const TextStyle(
        fontFamily: Coral.font,
        fontSize: 32,
        height: 1.12,
        fontWeight: FontWeight.w600,
        letterSpacing: -.8,
        color: Coral.ink,
      ),
      titleLarge: const TextStyle(
        fontFamily: Coral.font,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Coral.ink,
      ),
      bodyLarge: const TextStyle(
        fontFamily: Coral.font,
        fontSize: 16,
        height: 1.5,
        color: Coral.ink,
      ),
      bodyMedium: const TextStyle(
        fontFamily: Coral.font,
        fontSize: 16,
        height: 1.5,
        color: Coral.ink,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Coral.paper,
      foregroundColor: Coral.ink,
      surfaceTintColor: Coral.paper,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(style: button),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: button.copyWith(
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.focused) ? Coral.accent : Coral.rule,
            width: s.contains(WidgetState.focused) ? 3 : 1,
          ),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: button),
    cardTheme: CardThemeData(
      color: Coral.cotton,
      surfaceTintColor: Coral.cotton,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: shape.copyWith(side: const BorderSide(color: Coral.rule)),
    ),
    dividerTheme: const DividerThemeData(color: Coral.rule, space: 32),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Coral.cotton,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Coral.muted),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Coral.muted),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Coral.accent, width: 2),
      ),
      errorMaxLines: 3,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Coral.muted,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Coral.accent,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Coral.ink,
      contentTextStyle: TextStyle(
        fontFamily: Coral.font,
        color: Coral.cotton,
        fontSize: 16,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
