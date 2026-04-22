import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const Color primary = Color(0xFF6C63FF);
  const Color background = Color(0xFF1E1E2C);
  const Color surface = Color(0xFF2D2D44);
  const Color surfaceVariant = Color(0xFF3B3B54);
  const Color textPrimary = Color(0xFFFFFFFF);
  const Color textSecondary = Color(0xFFB0B0C3);
  const Color successColor = Color(0xFF26DE81);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: successColor,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      background: background,
      onBackground: textPrimary,
      error: const Color(0xFFFF6B6B),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: surfaceVariant, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textSecondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: successColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface,
      contentTextStyle: const TextStyle(color: textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: background,
      indicatorColor: primary.withValues(alpha: 0.3),
      labelTextStyle: MaterialStateProperty.resolveWith((Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return const TextStyle(color: primary, fontWeight: FontWeight.w600, fontSize: 12);
        }
        return const TextStyle(color: textSecondary, fontWeight: FontWeight.w500, fontSize: 12);
      }),
      iconTheme: MaterialStateProperty.resolveWith((Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return const IconThemeData(color: primary);
        }
        return const IconThemeData(color: textSecondary);
      }),
    ),
  );
}
