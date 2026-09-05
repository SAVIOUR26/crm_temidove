import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Central Material 3 theme. Every screen picks this up automatically via
/// `Theme.of(context)` / component defaults (Card, Chip, AppBar, etc.) —
/// screens shouldn't need to hardcode colors themselves except for the
/// semantic status colors in AppColors (paid/overdue/pending).
ThemeData buildAppTheme() {
  // ColorScheme.fromSeed gives us well-balanced container/surface tones,
  // but its own algorithm desaturates the seed itself for `primary` —
  // pin primary/secondary back to the exact brand hexes (see AppColors)
  // so buttons and the nav rail indicator read as the same blue/cyan as
  // the app icon and splash, not a washed-out M3 tone.
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primaryBlue,
    secondary: AppColors.accentCyan,
    tertiary: AppColors.accentGold,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primaryBlue,
    onPrimary: Colors.white,
    secondary: AppColors.accentCyan,
    onSecondary: Colors.white,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.surfaceTint,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surfaceTint,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.white,
      indicatorColor: colorScheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: colorScheme.primary),
      selectedLabelTextStyle: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedIconTheme: const IconThemeData(color: AppColors.neutral),
      unselectedLabelTextStyle: const TextStyle(
        color: AppColors.neutral,
        fontSize: 12,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      margin: EdgeInsets.zero,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      extendedTextStyle:
          const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
    ),
  );
}
